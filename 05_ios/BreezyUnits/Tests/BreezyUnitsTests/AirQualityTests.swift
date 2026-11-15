//
//  AirQualityTests.swift
//  BreezyUnits
//
//  The AQI is a piecewise-linear map, so the way to test it is at the breakpoints
//  and one point inside a band. Expected values are worked out from upstream's own
//  breakpoint tables by hand (and cross-checked in Python), not taken from the code.
//

import XCTest
@testable import BreezyUnits

final class PollutantIndexTests: XCTestCase {
    func testBreakpointsMapToAqiThresholds() {
        // At a breakpoint the index must land exactly on the scale value.
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 0), 0)
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 5), 20)
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 15), 50)
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 30), 100)
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 60), 150)
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 150), 250)
    }

    func testInterpolatesInsideABand() {
        // 10 µg/m³ PM2.5 is halfway between 5 (20) and 15 (50) -> 35.
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 10), 35)
        // O3 56 is 6/50 of the way from 50 (20) to 100 (50) -> 23.6 -> 24.
        XCTAssertEqual(PollutantIndex.index(of: .o3, concentration: 56), 24)
    }

    func testContinuesLinearlyAboveTheLastBreakpoint() {
        // Not clamped: 300 µg/m³ PM2.5 -> 300 * 250 / 150 = 500.
        XCTAssertEqual(PollutantIndex.index(of: .pm25, concentration: 300), 500)
        XCTAssertEqual(PollutantIndex.index(of: .no2, concentration: 1000), 250)
    }

    func testNilConcentrationHasNoIndex() {
        XCTAssertNil(PollutantIndex.index(of: .pm25, concentration: nil))
    }

    func testLevelsFollowTheScale() {
        XCTAssertEqual(PollutantIndex.level(forIndex: 0), 0)
        XCTAssertEqual(PollutantIndex.level(forIndex: 19), 0)
        XCTAssertEqual(PollutantIndex.level(forIndex: 20), 1)
        XCTAssertEqual(PollutantIndex.level(forIndex: 149), 3)
        XCTAssertEqual(PollutantIndex.level(forIndex: 150), 4)
        XCTAssertEqual(PollutantIndex.level(forIndex: 900), 5)
        XCTAssertNil(PollutantIndex.level(forIndex: nil))
    }

    func testOverallIndexIgnoresCarbonMonoxideAndSulphurDioxide() {
        // Upstream takes the max over O3, NO2, PM10 and PM25 only. A huge CO value
        // must not move the headline number, or the port disagrees with Android on
        // exactly the days anyone would compare.
        let air = AirQuality(
            pm25: 5.microgramsPerCubicMeter,     // index 20
            so2: 900.microgramsPerCubicMeter,    // index 234
            co: 10_000.microgramsPerCubicMeter   // index 10870
        )
        XCTAssertEqual(air.index, 20)
        // ...but asking about CO directly still works, for the detail page.
        XCTAssertEqual(air.index(for: Pollutant.co), 10870)
    }

    func testOverallIndexIsTheMaxOfTheFour() {
        let air = AirQuality(
            pm25: 10.microgramsPerCubicMeter,   // 35
            pm10: 80.microgramsPerCubicMeter,   // 100
            o3: 56.microgramsPerCubicMeter,     // 24
            no2: nil
        )
        XCTAssertEqual(air.index, 100)
        XCTAssertEqual(air.indexLevel, 3)
    }

    func testEmptyAirQualityHasNoIndex() {
        XCTAssertNil(AirQuality().index)
    }
}

final class OpenMeteoAirQualityTests: XCTestCase {
    private func fixture() throws -> OpenMeteoAirQualityResult {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Resources/airquality-berlin", withExtension: "json")
        )
        return try JSONDecoder().decode(OpenMeteoAirQualityResult.self, from: Data(contentsOf: url))
    }

    func testRequestShapeDiffersFromTheForecastCall() throws {
        let url = OpenMeteoAirQualityRequest.url(latitude: 52.52, longitude: 13.41)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let byName = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(components.host, "air-quality-api.open-meteo.com")
        XCTAssertEqual(components.path, "/v1/air-quality")
        XCTAssertEqual(byName["forecast_days"], "7")   // not 16
        XCTAssertEqual(byName["past_days"], "1")
        XCTAssertEqual(byName["timezone"], "auto")
        XCTAssertEqual(byName["timeformat"], "unixtime")
        XCTAssertEqual(byName["hourly"], "pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone")
        // This endpoint takes neither a model nor a wind-speed unit.
        XCTAssertNil(byName["models"])
        XCTAssertNil(byName["windspeed_unit"])
    }

    func testPollenVariablesAreOptIn() throws {
        let url = OpenMeteoAirQualityRequest.url(latitude: 0, longitude: 0, includePollen: true)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let hourly = try XCTUnwrap(components.queryItems?.first { $0.name == "hourly" }?.value)
        XCTAssertTrue(hourly.contains("ragweed_pollen"))
        XCTAssertTrue(hourly.hasPrefix("pm10,pm2_5"))
    }

    func testDecodesAndMapsTheRealPayload() throws {
        let result = try fixture()
        XCTAssertNil(result.error)
        let hourly = try XCTUnwrap(result.hourly)
        XCTAssertEqual(hourly.time.count, 192)   // 7 forecast days + 1 past day, 24 h

        let mapped = OpenMeteoMapping.airQualityByDate(from: hourly)
        XCTAssertEqual(mapped.count, 192)

        // Dictionary iteration order is unspecified, so pick the earliest hour
        // explicitly; `.values.first` made this test pass or fail at random.
        let earliestKey = try XCTUnwrap(mapped.keys.min())
        let first = try XCTUnwrap(mapped[earliestKey])
        XCTAssertNotNil(first.pm25)
        XCTAssertNotNil(first.o3)

        // Units are µg/m³ on the wire, so a plausible band is a real check.
        let index = try XCTUnwrap(first.index)
        XCTAssertTrue((0...500).contains(index), "implausible AQI from real data: \(index)")
    }

    func testMissingArraysYieldEmptyAirQualityRatherThanZero() throws {
        // A partial payload must not read as "perfectly clean air".
        let json = #"{"hourly": {"time": [1794708900]}}"#
        let result = try JSONDecoder().decode(OpenMeteoAirQualityResult.self, from: Data(json.utf8))
        let mapped = OpenMeteoMapping.airQualityByDate(from: try XCTUnwrap(result.hourly))
        XCTAssertEqual(mapped.count, 1)
        XCTAssertNil(mapped.values.first?.index)
    }
}