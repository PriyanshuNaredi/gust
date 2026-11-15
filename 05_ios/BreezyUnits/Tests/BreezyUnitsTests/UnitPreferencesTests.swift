//
//  UnitPreferencesTests.swift
//  BreezyUnits
//
//  Display-unit conversions. Each expected value is derived from the definition
//  (9/5 + 32, 1.609344 km per mile, 0.0393701 inHg per hPa), not read off the code.
//

import XCTest
@testable import BreezyUnits

final class UnitPreferencesTests: XCTestCase {
    func testFahrenheitConversion() {
        var prefs = UnitPreferences()
        prefs.temperature = .fahrenheit
        XCTAssertEqual(prefs.string(0.celsius, decimals: 0), "32 °F")
        XCTAssertEqual(prefs.string(100.celsius, decimals: 0), "212 °F")
        // (-40.0), not -40: the latter parses as -(40.celsius) and does not compile.
        XCTAssertEqual(prefs.string((-40.0).celsius, decimals: 0), "-40 °F")
        prefs.temperature = .celsius
        XCTAssertEqual(prefs.string(21.celsius, decimals: 0), "21 °C")
    }

    func testSpeedConversions() {
        // 1 m/s = 3.6 km/h = 2.236936 mph = 1.943844 kn
        var prefs = UnitPreferences()
        let speed = 1.0.metersPerSecond
        XCTAssertEqual(prefs.string(speed), "3.6 km/h")
        prefs.speed = .milesPerHour
        XCTAssertEqual(prefs.string(speed), "2.2 mph")
        prefs.speed = .knots
        XCTAssertEqual(prefs.string(speed), "1.9 kn")
        prefs.speed = .metersPerSecond
        XCTAssertEqual(prefs.string(speed), "1.0 m/s")
        // Beaufort is a band, so assert the band rather than the exact number.
        prefs.speed = .beaufort
        XCTAssertEqual(prefs.string(5.0.metersPerSecond), "3 Bft")
    }

    func testPressureConversions() {
        // 1013.25 hPa = 760 mmHg = 29.92 inHg
        var prefs = UnitPreferences()
        let pressure = 1013.25.hectopascals
        // Storage is an integer pascal count, so 1013.25 hPa is exactly 101325 Pa;
        // printf then rounds 1013.25 to 1013.2 (binary 1013.2499…). Pinning the real
        // output keeps this honest rather than aspirational.
        XCTAssertEqual(prefs.string(pressure), "1013.2 hPa")
        prefs.pressure = .millimetersOfMercury
        XCTAssertEqual(prefs.string(pressure), "760.0 mmHg")
        // inHg keeps two decimals, or every reading looks identical.
        prefs.pressure = .inchesOfMercury
        XCTAssertEqual(prefs.string(pressure), "29.92 inHg")
    }

    func testPrecipitationAndDistanceConversions() {
        var prefs = UnitPreferences()
        XCTAssertEqual(prefs.string(25.4.millimeters), "25.4 mm")
        prefs.precipitation = .inches
        XCTAssertEqual(prefs.string(25.4.millimeters), "1.00 in")

        XCTAssertEqual(prefs.string(1.0.kilometers), "1.0 km")
        prefs.distance = .miles
        XCTAssertEqual(prefs.string(1.0.kilometers), "0.6 mi")
        prefs.distance = .meters
        XCTAssertEqual(prefs.string(1.0.kilometers), "1000 m")
    }

    func testFormattingUsesTheChosenUnitAndHandlesNil() {
        var prefs = UnitPreferences()
        XCTAssertEqual(prefs.string(12.34.celsius), "12.3 °C")
        prefs.temperature = .fahrenheit
        // Temperature is stored as integer deci-Celsius, so 12.34 → 12.3 °C → 54.1 °F.
        // The rounding is upstream's storage model, not a formatting bug.
        XCTAssertEqual(prefs.string(12.34.celsius), "54.1 °F")
        XCTAssertEqual(prefs.degrees(12.34.celsius), "54°")

        prefs.pressure = .inchesOfMercury
        XCTAssertEqual(prefs.string(1013.25.hectopascals), "29.92 inHg")

        // Absent data must render as an em dash, never as zero.
        XCTAssertEqual(prefs.string(nil as Temperature?), "—")
        XCTAssertEqual(prefs.string(nil as Speed?), "—")
    }

    func testPreferencesRoundTripThroughCodable() throws {
        // These are persisted in UserDefaults; a silent decode failure would reset
        // every unit on launch.
        var prefs = UnitPreferences()
        prefs.temperature = .fahrenheit
        prefs.speed = .milesPerHour
        prefs.pressure = .inchesOfMercury
        prefs.precipitation = .inches
        prefs.distance = .miles
        prefs.twelveHourClock = true

        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(UnitPreferences.self, from: data)
        XCTAssertEqual(decoded, prefs)
    }

    func testBeaufortFormattingHasNoDecimals() {
        var prefs = UnitPreferences()
        prefs.speed = .beaufort
        // "3 Bft", not "3.0 Bft": Beaufort is an integer band.
        XCTAssertEqual(prefs.string(5.0.metersPerSecond), "3 Bft")
    }
}
