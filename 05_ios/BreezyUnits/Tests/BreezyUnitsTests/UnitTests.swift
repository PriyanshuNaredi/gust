//
//  UnitTests.swift
//  BreezyUnits
//
//  Slice 2: Speed, Distance, Pressure, Ratio, and the computing functions they
//  unblock. Conversion expectations are derived from upstream's closure bodies;
//  the `feels like` values were computed independently from the same formulas
//  (Python) rather than by running the Swift code, so the test can actually fail.
//

import XCTest
@testable import BreezyUnits

final class SpeedTests: XCTestCase {
    func testMetricAndImperialConversions() {
        // 36 km/h == 10 m/s exactly, by upstream's 0.036 factor.
        XCTAssertEqual(36.0.kilometersPerHour.inMetersPerSecond, 10.0, accuracy: 0.001)
        XCTAssertEqual(10.0.metersPerSecond.inKilometersPerHour, 36.0, accuracy: 0.001)
        XCTAssertEqual(100.0.kilometersPerHour.inMilesPerHour, 62.137, accuracy: 0.01)
        XCTAssertEqual(1.0.metersPerSecond.inKnots, 1.9438, accuracy: 0.001)
        XCTAssertEqual(1.0.metersPerSecond.inFeetPerSecond, 3.2808, accuracy: 0.001)
    }

    func testBeaufortBoundaries() {
        // Upstream switches on the integer cm/s value with these exact edges.
        XCTAssertEqual(0.30.metersPerSecond.inBeaufort, 1)   // 30 cm/s
        XCTAssertEqual(0.29.metersPerSecond.inBeaufort, 0)
        XCTAssertEqual(3.4.metersPerSecond.inBeaufort, 3)    // 340 cm/s
        XCTAssertEqual(32.7.metersPerSecond.inBeaufort, 12)  // 3270 cm/s and above
        XCTAssertEqual(9.beaufort.inBeaufort, 9)
    }

    func testComparisonUsesReferenceUnit() {
        XCTAssertTrue(1.0.metersPerSecond > 0.5.metersPerSecond)
        XCTAssertEqual(1.0.metersPerSecond, 3.6.kilometersPerHour)
    }
}

final class DistanceTests: XCTestCase {
    func testConversions() {
        XCTAssertEqual(1000.0.meters.inKilometers, 1.0, accuracy: 0.001)
        // Storage is an Int64 metre count, so a mile rounds to 1609 m on the way in
        // and reads back as 1.609 km. That is upstream's behaviour too (its rawValue
        // is a Long) -- sub-metre precision is not preserved, and for visibility
        // display it does not need to be. Asserted as-is so the rounding is
        // documented rather than rediscovered later.
        XCTAssertEqual(1.0.miles.inKilometers, 1.609, accuracy: 0.0001)
        XCTAssertEqual(1.0.nauticalMiles.inKilometers, 1.852, accuracy: 0.0001)
        XCTAssertEqual(1.0.meters.inFeet, 3.28084, accuracy: 0.0001)
        // Whole kilometres stay exact.
        XCTAssertEqual(5.kilometers.inMeters, 5000.0, accuracy: 0.0001)
    }
}

final class PressureTests: XCTestCase {
    func testConversions() {
        XCTAssertEqual(1013.25.hectopascals.inHectopascals, 1013.25, accuracy: 0.01)
        XCTAssertEqual(1013.25.hectopascals.inMillibars, 1013.25, accuracy: 0.01)
        XCTAssertEqual(1013.25.hectopascals.inKilopascals, 101.325, accuracy: 0.001)
        XCTAssertEqual(101_325.pascals.inAtmospheres, 1.0, accuracy: 0.0001)
        XCTAssertEqual(1013.25.hectopascals.inMillimetersOfMercury, 760.0, accuracy: 0.1)
        XCTAssertEqual(1013.25.hectopascals.inInchesOfMercury, 29.92, accuracy: 0.02)
    }
}

final class RatioTests: XCTestCase {
    func testConversions() {
        XCTAssertEqual(500.permille.inPercent, 50.0, accuracy: 0.001)
        XCTAssertEqual(50.percent.inFraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(1.fraction.inPermille, 1000.0, accuracy: 0.001)
    }

    func testClamp() {
        XCTAssertEqual(1500.permille.clamped.referenceValue, 1000)
        XCTAssertEqual((-10).permille.clamped.referenceValue, 0)
        XCTAssertEqual(500.permille.clamped.referenceValue, 500)
    }
}

final class FeelsLikeTests: XCTestCase {
    // Values computed from the upstream formulas, independently of this Swift code.
    func testApparentTemperature() {
        XCTAssertNil(computeApparentTemperature(temperature: nil, relativeHumidity: 50.percent, windSpeed: 3.0.metersPerSecond))
        XCTAssertNil(computeApparentTemperature(temperature: 25.celsius, relativeHumidity: nil, windSpeed: 3.0.metersPerSecond))
        XCTAssertNil(computeApparentTemperature(temperature: 25.celsius, relativeHumidity: 50.percent, windSpeed: nil))

        XCTAssertEqual(
            computeApparentTemperature(temperature: 25.celsius, relativeHumidity: 50.percent, windSpeed: 3.0.metersPerSecond)?.inCelsius ?? .nan,
            24.11, accuracy: 0.05
        )
        XCTAssertEqual(
            computeApparentTemperature(temperature: 30.celsius, relativeHumidity: 70.percent, windSpeed: 2.0.metersPerSecond)?.inCelsius ?? .nan,
            34.37, accuracy: 0.05
        )
    }

    func testWindChill() {
        // Above 10 °C there is no wind chill at all.
        XCTAssertNil(computeWindChillTemperature(temperature: 11.celsius, windSpeed: 20.0.kilometersPerHour))
        XCTAssertNil(computeWindChillTemperature(temperature: 5.celsius, windSpeed: 3.0.kilometersPerHour)) // warm + calm

        XCTAssertEqual(
            computeWindChillTemperature(temperature: 0.celsius, windSpeed: 20.0.kilometersPerHour)?.inCelsius ?? .nan,
            -5.24, accuracy: 0.05
        )
        XCTAssertEqual(
            computeWindChillTemperature(temperature: (-5).celsius, windSpeed: 30.0.kilometersPerHour)?.inCelsius ?? .nan,
            -13.0, accuracy: 0.05
        )
        // The cold/calm branch: the simplified formula, which is a different curve.
        XCTAssertEqual(
            computeWindChillTemperature(temperature: (-2).celsius, windSpeed: 3.0.kilometersPerHour)?.inCelsius ?? .nan,
            -3.12, accuracy: 0.05
        )
    }

    func testTotalProbabilityTakesMaxNotSum() {
        XCTAssertNil(computeTotalProbabilityOfPrecipitation(thunderstorm: nil, rain: nil, snow: nil, ice: nil))
        XCTAssertEqual(
            computeTotalProbabilityOfPrecipitation(thunderstorm: nil, rain: 30.percent, snow: 60.percent, ice: nil)?.inPercent ?? .nan,
            60.0, accuracy: 0.001
        )
        XCTAssertEqual(
            computeTotalProbabilityOfPrecipitation(thunderstorm: 80.percent, rain: 20.percent, snow: nil, ice: nil)?.inPercent ?? .nan,
            80.0, accuracy: 0.001
        )
    }
}
