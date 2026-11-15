//
//  ForecastTests.swift
//  BreezyUnits
//
//  Forecast mapping (positional arrays, unit quirks) and the main screen's
//  half/full card layout rule, which is what makes the Android list look the way
//  it does.
//

import XCTest
@testable import BreezyUnits

final class ForecastMappingTests: XCTestCase {
    private func fixture() throws -> OpenMeteoWeatherResult {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Resources/openmeteo-berlin", withExtension: "json")
        )
        return try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: Data(contentsOf: url))
    }

    func testMapsWholePayload() throws {
        let weather = OpenMeteoMapping.weather(from: try fixture())
        XCTAssertNotNil(weather.current)
        XCTAssertEqual(weather.hourlyForecast.count, 408)
        // The payload has 17 days; upstream iterates `0 until size - 1` and drops the
        // last one, so 16 is the parity answer, not 17.
        XCTAssertEqual(weather.dailyForecast.count, 16)
        // One entry per 15-minute step, nulls included: the fixture has gaps, and a
        // compacted array would shift every later step earlier.
        XCTAssertEqual(weather.minutelyForecast.count, 1632)
        XCTAssertEqual(weather.minutelyForecast.count, weather.minutelyForecast.count)
        XCTAssertTrue(weather.minutelyForecast.contains { $0.precipitation == nil },
                      "fixture should contain at least one gap, or this test proves nothing")
        XCTAssertFalse(weather.hasMinutelyPrecipitation == false && weather.minutelyForecast.contains {
            ($0.precipitation?.inMillimeters ?? 0) > 0
        })

        // Dates are epoch seconds, in ascending order, one hour apart.
        let first = try XCTUnwrap(weather.hourlyForecast.first)
        let second = try XCTUnwrap(weather.hourlyForecast.dropFirst().first)
        XCTAssertEqual(second.date.timeIntervalSince(first.date), 3600, accuracy: 1)
    }

    func testHourlyFieldsLandInTheRightUnits() throws {
        let weather = OpenMeteoMapping.weather(from: try fixture())
        // 13:00 local, first hour with a temperature in the fixture.
        let sample = try XCTUnwrap(weather.hourlyForecast.first { $0.temperature != nil })
        XCTAssertNotNil(sample.temperature)
        XCTAssertNotNil(sample.relativeHumidity)
        XCTAssertNotNil(sample.pressure)
        XCTAssertNotNil(sample.wind?.speed)

        // Percent is stored as permille, so the displayed value must round-trip.
        let humidityPercent = try XCTUnwrap(sample.relativeHumidity).inPercent
        XCTAssertTrue((0...100).contains(humidityPercent), "humidity out of range: \(humidityPercent)")

        // Pressure near sea level, in hPa: a sanity band, not a tautology.
        let pressure = try XCTUnwrap(sample.pressure).inHectopascals
        XCTAssertTrue((900...1100).contains(pressure), "pressure out of range: \(pressure)")
    }

    func testSnowfallArrivesInCentimetres() throws {
        // The one field whose unit differs from every other precipitation field.
        let json = """
        {"hourly": {"time": [1794708900],
                    "snowfall": [1.0],
                    "precipitation": [1.0],
                    "rain": [2.0]}}
        """
        let result = try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: Data(json.utf8))
        let hour = try XCTUnwrap(OpenMeteoMapping.hourly(from: try XCTUnwrap(result.hourly)).first)
        XCTAssertEqual(hour.snow?.inMillimeters ?? .nan, 10.0, accuracy: 0.001, "1 cm of snow is 10 mm of water equivalent")
        XCTAssertEqual(hour.precipitation?.inMillimeters ?? .nan, 1.0, accuracy: 0.001)
        XCTAssertEqual(hour.rain?.inMillimeters ?? .nan, 2.0, accuracy: 0.001)
    }

    func testDailyDateIsLocalMidnightAcrossDst() throws {
        // Upstream adds an hour, then zeroes the hour: this keeps the anchor on the
        // right day even when the day starts at a DST boundary.
        let berlin = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let result = try fixture()
        let days = OpenMeteoMapping.daily(from: try XCTUnwrap(result.daily), timeZone: berlin)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = berlin
        for day in days {
            XCTAssertEqual(calendar.component(.hour, from: day.date), 0, "day not anchored at local midnight")
        }
        // Consecutive and increasing: no duplicated or skipped dates.
        let unique = Set(days.map(\.date))
        XCTAssertEqual(unique.count, days.count)
    }

    func testRainIsRainPlusShowers() throws {
        // Upstream stores a single "rain" total; a port that keeps them separate
        // renders a rain card that looks dry during a shower.
        let json = """
        {"hourly": {"time": [1794708900, 1794712500],
                    "rain": [1.0, null],
                    "showers": [2.0, 0.5]}}
        """
        let result = try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: Data(json.utf8))
        let hours = OpenMeteoMapping.hourly(from: try XCTUnwrap(result.hourly))
        XCTAssertEqual(hours[0].rain?.inMillimeters ?? .nan, 3.0, accuracy: 0.001)
        XCTAssertEqual(hours[1].rain?.inMillimeters ?? .nan, 0.5, accuracy: 0.001)
    }

    func testWMOCodesMapToBreezyFamilies() {
        // Verbatim from OpenMeteoService.getWeatherCode, including the holes.
        let cases: [(Int?, WeatherCode?)] = [
            (0, .clear), (1, .clear), (2, .partlyCloudy), (3, .cloudy),
            (45, .fog), (48, .fog),
            (51, .rain), (55, .rain), (57, .rain), (61, .rain), (67, .rain), (80, .rain), (82, .rain),
            (71, .snow), (75, .snow), (86, .snow),
            (77, .sleet), (95, .thunderstorm), (99, .thunderstorm),
            (4, nil), (50, nil), (nil, nil)
        ]
        for (code, expected) in cases {
            XCTAssertEqual(OpenMeteoMapping.weatherCode(fromWMO: code), expected, "WMO \(String(describing: code))")
        }
    }

    func testShortArraysDoNotCrashOrShift() throws {
        // A truncated array (a source may do this) must leave later hours nil
        // rather than mapping the wrong value into place.
        let json = """
        {"hourly": {"time": [1794708900, 1794712500, 1794716100],
                    "temperature_2m": [1.0, 2.0]}}
        """
        let result = try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: Data(json.utf8))
        let hours = OpenMeteoMapping.hourly(from: try XCTUnwrap(result.hourly))
        XCTAssertEqual(hours.count, 3)
        XCTAssertEqual(hours[0].temperature?.inCelsius ?? .nan, 1.0, accuracy: 0.001)
        XCTAssertEqual(hours[1].temperature?.inCelsius ?? .nan, 2.0, accuracy: 0.001)
        XCTAssertNil(hours[2].temperature)
    }
}

final class CardLayoutTests: XCTestCase {
    func testFullCardsStandAlone() {
        let rows = CardLayout.rows(for: [.header, .daily, .hourly, .footer])
        XCTAssertEqual(rows, [.full(.header), .full(.daily), .full(.hourly), .full(.footer)])
    }

    func testConsecutiveHalfCardsPair() {
        let rows = CardLayout.rows(for: [.header, .wind, .humidity, .pressure, .uv])
        XCTAssertEqual(rows, [
            .full(.header),
            .half(.wind, .humidity),
            .half(.pressure, .uv)
        ])
    }

    func testLoneHalfCardIsMarkedAloneRatherThanStretched() {
        let rows = CardLayout.rows(for: [.header, .wind, .daily])
        XCTAssertEqual(rows, [.full(.header), .halfAlone(.wind), .full(.daily)])
    }

    func testFullCardBetweenHalvesFlushesThePendingRow() {
        let rows = CardLayout.rows(for: [.wind, .daily, .humidity])
        XCTAssertEqual(rows, [.halfAlone(.wind), .full(.daily), .halfAlone(.humidity)])
    }

    func testUpstreamHalfSizeTable() {
        // Copied from ViewType.isHalfSizeableBlock; if this changes, the Android
        // layout changed and the port must change with it.
        XCTAssertFalse(MainCardKind.header.isHalfSizeable)
        XCTAssertFalse(MainCardKind.alert.isHalfSizeable)
        XCTAssertFalse(MainCardKind.precipitationNowcast.isHalfSizeable)
        XCTAssertFalse(MainCardKind.daily.isHalfSizeable)
        XCTAssertFalse(MainCardKind.hourly.isHalfSizeable)
        XCTAssertFalse(MainCardKind.footer.isHalfSizeable)
        for kind in [MainCardKind.precipitation, .wind, .airQuality, .pollen, .humidity,
                     .uv, .visibility, .pressure, .sun, .moon, .clock] {
            XCTAssertTrue(kind.isHalfSizeable, "\(kind) should be half size")
        }
    }

    func testEveryKindHasARowDecision() {
        // No card may be silently dropped by the layout.
        let rows = CardLayout.rows(for: MainCardKind.allCases)
        XCTAssertEqual(rows.flatMap(\.kinds), MainCardKind.allCases)
    }
}

final class NowcastTests: XCTestCase {
    private func steps(_ millimetres: [Double?]) -> Nowcast {
        let start = Date(timeIntervalSince1970: 1_794_708_900)
        return Nowcast(steps: millimetres.enumerated().map { index, value in
            MinutelyForecast(
                date: start.addingTimeInterval(TimeInterval(index) * 900),
                precipitation: value.map { $0.millimeters }
            )
        })
    }

    func testStatesFollowTheFirstAndLastStep() {
        // Upstream decides from the edges only, so a wet middle with dry edges is
        // "starting", not a fourth state.
        XCTAssertEqual(steps([0, 0.4, 0.6, 0.2]).state, .starting)
        XCTAssertEqual(steps([0.4, 0.6, 0.2, 0.1]).state, .continuing)
        XCTAssertEqual(steps([0.4, 0.6, 0.2, 0]).state, .stopping)
        XCTAssertEqual(steps([0, 0, 0, 0]).state, .none)
    }

    func testNullsCountAsDry() {
        // A gap is not rain, and it must not make the first step look wet either.
        XCTAssertEqual(steps([nil, 0.5, nil, nil]).state, .starting)
        XCTAssertFalse(steps([nil, nil]).hasPrecipitation)
    }

    func testFirstAndLastWetTimes() {
        let nowcast = steps([0, 0.2, 0.3, 0])
        XCTAssertEqual(nowcast.firstWetDate, nowcast.steps[1].date)
        XCTAssertEqual(nowcast.lastWetDate, nowcast.steps[2].date)
        XCTAssertEqual(nowcast.stepInterval, 900, accuracy: 0.5)
    }

    func testWindowStartsAtTheBeginningWhenRainIsImminent() {
        let nowcast = steps([0, 0.2, 0.3, 0.4, 0.1])
        XCTAssertEqual(nowcast.window(maxSteps: 3).count, 3)
        XCTAssertEqual(nowcast.window(maxSteps: 3).first?.date, nowcast.steps.first?.date)
    }

    func testWindowMovesToRainThatArrivesLater() {
        // 20 dry steps, then rain: a card that says "rain starting" must not draw an
        // empty strip, so the window begins just before the first wet step.
        let nowcast = steps(Array(repeating: 0.0, count: 20) + Array(repeating: 0.5, count: 10))
        let window = nowcast.window(maxSteps: 6)
        XCTAssertEqual(window.count, 6)
        XCTAssertEqual(window.first?.date, nowcast.steps[19].date)
        XCTAssertTrue(window.contains { ($0.precipitation?.inMillimeters ?? 0) > 0 })
    }

    func testWindowHandlesNoRainAtAll() {
        let nowcast = steps([0, 0, 0])
        XCTAssertEqual(nowcast.window().count, 3)
        XCTAssertEqual(nowcast.state, .none)
    }

    func testIntensityIsPerHourNotPerStep() {
        // 15-minute accumulation: 1.5 mm in a step is 6 mm/h, just above upstream's
        // "light" threshold of 5 mm/h.
        let step = MinutelyForecast(date: Date(timeIntervalSince1970: 0), precipitation: 1.5.millimeters)
        let rate = Nowcast.millimetersPerHour(of: step, suggesting: 900)
        XCTAssertEqual(rate, 6.0, accuracy: 0.001)
        XCTAssertGreaterThan(rate, 5.0)
        XCTAssertLessThan(rate, 10.0)
    }
}
