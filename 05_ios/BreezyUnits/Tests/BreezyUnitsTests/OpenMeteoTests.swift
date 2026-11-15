//
//  OpenMeteoTests.swift
//  BreezyUnits
//
//  The fixture is a real payload from api.open-meteo.com, recorded with the exact
//  request upstream's OpenMeteoService builds for Berlin. Tests therefore check the
//  port against the service's actual shape, including its nulls and its 15-minute
//  arrays, without any network access.
//

import XCTest
@testable import BreezyUnits

final class OpenMeteoRequestTests: XCTestCase {
    func testRequestMatchesUpstreamParameters() throws {
        let url = OpenMeteoRequest.url(latitude: 52.52, longitude: 13.41)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(url.path, "/v1/forecast")
        XCTAssertEqual(byName["timezone"], "auto")
        XCTAssertEqual(byName["timeformat"], "unixtime")
        XCTAssertEqual(byName["windspeed_unit"], "ms")
        XCTAssertEqual(byName["forecast_days"], "16")
        XCTAssertEqual(byName["past_days"], "1")
        XCTAssertEqual(byName["models"], "best_match")

        // Variable counts are parity: upstream sends 21 daily, 18 hourly, 12 current.
        // Ours is 23 daily because sunrise/sunset were added (documented deviation).
        XCTAssertEqual(byName["daily"]?.split(separator: ",").count, 23)
        XCTAssertEqual(byName["hourly"]?.split(separator: ",").count, 18)
        XCTAssertEqual(byName["current"]?.split(separator: ",").count, 12)
        XCTAssertEqual(byName["minutely_15"], "precipitation")
    }

    func testVariableOrderIsUpstreamOrder() {
        // Order matters: Open-Meteo returns arrays positionally per variable name,
        // and a reordered list is a silent mis-mapping. Pin the head and tail.
        XCTAssertEqual(OpenMeteoRequest.dailyVariables.first, "temperature_2m_max")
        XCTAssertEqual(OpenMeteoRequest.dailyVariables.first { $0 == "visibility_min" }, "visibility_min")
        // The two extra variables are appended, so upstream's order is untouched.
        XCTAssertEqual(Array(OpenMeteoRequest.dailyVariables.suffix(2)), ["sunrise", "sunset"])
        XCTAssertEqual(OpenMeteoRequest.hourlyVariables.first, "temperature_2m")
        XCTAssertEqual(OpenMeteoRequest.hourlyVariables.last, "visibility")
        XCTAssertEqual(OpenMeteoRequest.currentVariables.first, "temperature_2m")
        XCTAssertEqual(OpenMeteoRequest.currentVariables.last, "visibility")
    }

    func testPartialFeaturesSendEmptyStrings() throws {
        // Upstream sends "" rather than omitting the key when a feature is off.
        let url = OpenMeteoRequest.url(
            latitude: 0, longitude: 0, includeForecast: false, includeCurrent: true, includeMinutely: false
        )
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(byName["daily"], "")
        XCTAssertEqual(byName["hourly"], "")
        XCTAssertEqual(byName["minutely_15"], "")
        XCTAssertFalse(byName["current"]!.isEmpty)
    }
}

final class OpenMeteoDecodingTests: XCTestCase {
    private func fixture() throws -> OpenMeteoWeatherResult {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Resources/openmeteo-berlin", withExtension: "json"),
            "fixture missing from test bundle"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: data)
    }

    func testDecodesRealPayload() throws {
        let result = try fixture()
        XCTAssertNil(OpenMeteoMapping.failureReason(in: result))
        XCTAssertEqual(result.timezone, "Europe/Berlin")

        // Shape from the live service with upstream's request: 16 forecast days plus
        // one past day, hourly at 1 h, minutely_15 at 15 min (168 h × 4 = 672 slots
        // per 7 days; the service returns what the model covers).
        XCTAssertEqual(result.daily?.time.count, 17)
        XCTAssertEqual(result.hourly?.time.count, 408)
        XCTAssertEqual(result.minutelyFifteen?.time.count, 1632)
    }

    func testMapsCurrentObservationWithCorrectUnits() throws {
        let result = try fixture()
        let raw = try XCTUnwrap(result.current)
        let current = OpenMeteoMapping.current(from: raw)

        // Values are the fixture's, so this asserts unit conversion, not the weather.
        XCTAssertEqual(current.temperature?.inCelsius ?? .nan, raw.temperature ?? .nan, accuracy: 0.001)
        XCTAssertEqual(current.temperature?.inFahrenheit ?? .nan,
                       9.0 / 5.0 * (raw.temperature ?? .nan) + 32, accuracy: 0.05)

        // windSpeed arrives in m/s (windspeed_unit=ms) and must become km/h correctly.
        XCTAssertEqual(current.wind?.speed?.inMetersPerSecond ?? .nan, raw.windSpeed ?? .nan, accuracy: 0.001)
        XCTAssertEqual(current.wind?.speed?.inKilometersPerHour ?? .nan,
                       (raw.windSpeed ?? .nan) * 3.6, accuracy: 0.01)

        // hPa stays hPa through the pascal reference unit.
        XCTAssertEqual(current.pressure?.inHectopascals ?? .nan, raw.pressureMsl ?? .nan, accuracy: 0.001)

        // Percent → permille reference → percent round-trips.
        XCTAssertEqual(current.relativeHumidity?.inPercent ?? .nan,
                       Double(raw.relativeHumidity ?? -1), accuracy: 0.001)

        // Visibility arrives in metres.
        XCTAssertEqual(current.visibility?.inMeters ?? .nan, raw.visibility ?? .nan, accuracy: 0.001)

        // Cloud cover is a ratio, not a raw number, once mapped.
        XCTAssertEqual(current.cloudCover?.inPercent ?? .nan, Double(raw.cloudCover ?? -1), accuracy: 0.001)
    }

    func testNullsSurviveMapping() throws {
        // Every field optional: a source may omit anything, and the UI decides what
        // to hide. Build a minimal payload with only a timestamp.
        let json = #"{"current": {"time": 1794708900}}"#
        let result = try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: Data(json.utf8))
        let raw = try XCTUnwrap(result.current)
        let current = OpenMeteoMapping.current(from: raw)

        XCTAssertNil(current.temperature)
        XCTAssertNil(current.wind?.speed)
        XCTAssertNil(current.pressure)
        XCTAssertEqual(current.date.timeIntervalSince1970, 1794708900, accuracy: 0.5)
    }

    func testErrorBodyWithHTTP200IsDetected() throws {
        // Open-Meteo reports some failures in the body; decoding succeeds, so the
        // success check must live outside the decoder.
        let json = #"{"error": true, "reason": "No data is available for this location"}"#
        let result = try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: Data(json.utf8))
        XCTAssertEqual(OpenMeteoMapping.failureReason(in: result),
                       "No data is available for this location")

        // ...and an empty-but-valid body is also a failure, not an empty forecast.
        let empty = try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: Data("{}".utf8))
        XCTAssertNotNil(OpenMeteoMapping.failureReason(in: empty))
    }
}
