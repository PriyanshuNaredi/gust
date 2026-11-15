//
//  PortedTests.swift
//  BreezyUnits
//
//  Every assertion below is taken from Breezy Weather's own test suite
//  (`weather-unit/src/test/kotlin/org/breezyweather/unit/`), tag v6.2.2 — so the
//  Swift port is checked against the behaviour the Android app actually ships,
//  not against what we assume it does.
//
//  Deliberately NOT ported: the upstream formatting tests, which mock an Android
//  `Context` to feed resource strings. Those verify Android resource plumbing,
//  not arithmetic. Our formatting layer is tested separately.
//

import XCTest
@testable import BreezyUnits

final class TemperatureTests: XCTestCase {
    // from `TemperatureTest.kt`: convert from reference unit to Fahrenheit
    func testDeciCelsiusToFahrenheit() {
        XCTAssertEqual(0.deciCelsius.inFahrenheit, 32.0)
        XCTAssertEqual(100.deciCelsius.inFahrenheit, 50.0)
    }

    // from `TemperatureTest.kt`: convert from Fahrenheit to reference unit
    func testFahrenheitToReferenceUnit() {
        XCTAssertEqual(32.0.fahrenheit.referenceValue, 0)
        XCTAssertEqual(50.0.fahrenheit.referenceValue, 100)
    }

    // from `TemperatureTest.kt`: convert from Celsius to Fahrenheit
    func testCelsiusToFahrenheit() {
        XCTAssertEqual(0.celsius.inFahrenheit, 32.0)
        XCTAssertEqual(10.celsius.inFahrenheit, 50.0)
    }

    // from `TemperatureTest.kt`: convert from Celsius to Kelvin
    func testCelsiusToKelvin() {
        XCTAssertEqual(0.celsius.inKelvins, 273.15)
        XCTAssertEqual(10.celsius.inKelvins, 283.15)
    }

    func testComparisonUsesReferenceUnit() {
        XCTAssertTrue(0.celsius < 1.celsius)
        XCTAssertEqual(0.celsius, 0.deciCelsius)
        XCTAssertTrue(32.0.fahrenheit == 0.celsius)
    }

    func testNaNIsRejected() {
        XCTAssertThrowsError(try Temperature(Double.nan, unit: .celsius))
    }
}

final class PrecipitationTests: XCTestCase {
    // from `PrecipitationComputingTest.kt`: computeTotalPrecipitationTest
    func testComputeTotalPrecipitation() {
        XCTAssertNil(computeTotalPrecipitation(temperature: nil, rain: nil, snow: nil, ice: nil))

        // 2 °C: ratio interpolates to ~6.0 → 1 cm snow becomes 10 mm water.
        XCTAssertEqual(
            computeTotalPrecipitation(temperature: 2.0.celsius, rain: 20.0.millimeters, snow: 1.0.centimeters, ice: nil)?.inMillimeters,
            30.0
        )
        XCTAssertEqual(
            computeTotalPrecipitation(temperature: 0.0.celsius, rain: nil, snow: 3.0.centimeters, ice: nil)?.inMillimeters,
            10.0
        )
        XCTAssertEqual(
            computeTotalPrecipitation(temperature: 0.0.celsius, rain: nil, snow: nil, ice: 2.0.centimeters)?.inMillimeters,
            18.4
        )
        XCTAssertEqual(
            computeTotalPrecipitation(temperature: 0.0.celsius, rain: 50.0.millimeters, snow: 6.0.centimeters, ice: 1.0.centimeters)?.inMillimeters,
            79.2
        )
        XCTAssertEqual(
            computeTotalPrecipitation(temperature: (-1.0).celsius, rain: nil, snow: 5.0.centimeters, ice: nil)?.inMillimeters,
            10.0
        )
        XCTAssertEqual(
            computeTotalPrecipitation(temperature: (-6.0).celsius, rain: nil, snow: 4.5.centimeters, ice: nil)?.inMillimeters,
            5.0
        )
    }

    func testSnowRatioInterpolates() {
        // -30 °C and -26 °C are table rows; -28 °C is a row too. -25 °C is between
        // -26 (7.0) and -24 (8.8) and must interpolate, not step.
        XCTAssertEqual(snowToLiquidRatio(temperature: (-30.0).celsius), 7.2, accuracy: 0.001)
        XCTAssertEqual(snowToLiquidRatio(temperature: (-26.0).celsius), 7.0, accuracy: 0.001)
        XCTAssertEqual(snowToLiquidRatio(temperature: (-25.0).celsius), 7.9, accuracy: 0.001)
        XCTAssertEqual(snowToLiquidRatio(temperature: nil), 7.2, accuracy: 0.001)
    }

    func testUnitConversions() {
        XCTAssertEqual(1.0.inches.inMillimeters, 25.4, accuracy: 0.001)
        XCTAssertEqual(1.0.centimeters.inMillimeters, 10.0, accuracy: 0.001)
    }
}

final class TemperatureComputingTests: XCTestCase {
    // from `TemperatureComputingTest.kt`: computeHumidexTest
    func testComputeHumidex() {
        XCTAssertNil(computeHumidex(temperature: nil, dewPoint: nil))
        XCTAssertNil(computeHumidex(temperature: nil, dewPoint: 13.0.celsius))
        XCTAssertNil(computeHumidex(temperature: 20.0.celsius, dewPoint: nil))
        XCTAssertEqual(computeHumidex(temperature: 20.0.celsius, dewPoint: 13.0.celsius)?.inCelsius ?? .nan, 22.8, accuracy: 0.05)
        XCTAssertEqual(computeHumidex(temperature: 39.0.celsius, dewPoint: 26.0.celsius)?.inCelsius ?? .nan, 52.5, accuracy: 0.05)
    }
}
