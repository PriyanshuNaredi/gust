//
//  BackdropTests.swift
//  BreezyUnits
//
//  The background colour table is copied from upstream, so these tests pin the
//  upstream literals rather than "something bluish".
//

import XCTest
@testable import BreezyUnits

final class BackdropTests: XCTestCase {
    func testDayColoursMatchUpstreamLiterals() {
        let cases: [(WeatherKind, RGB)] = [
            (.clear, RGB(red: 253, green: 188, blue: 76)),
            (.cloud, RGB(hex: 0x00A5D9)),      // -0xff5a27
            (.cloudy, RGB(hex: 0x9DAFC1)),     // -0x62503f
            (.fog, RGB(hex: 0xA3AEC2)),        // -0x5c513e
            (.haze, RGB(hex: 0xE1C899)),       // -0x1e3767
            (.rain, RGB(hex: 0x4297E7)),       // -0xbd6819
            (.sleet, RGB(hex: 0x68BAFF)),      // -0x974501
            (.snow, RGB(hex: 0x68BAFF)),
            (.hail, RGB(hex: 0x68BAFF)),
            (.thunder, RGB(hex: 0xB296BD)),    // -0x4d6943
            (.thunderstorm, RGB(hex: 0xB296BD)),
            (.wind, RGB(hex: 0xEACDA3))        // -0x15325d
        ]
        for (kind, expected) in cases {
            let actual = WeatherBackdrop.baseColor(kind, daylight: true)
            XCTAssertEqual(actual.red, expected.red, accuracy: 0.001, "\(kind) red")
            XCTAssertEqual(actual.green, expected.green, accuracy: 0.001, "\(kind) green")
            XCTAssertEqual(actual.blue, expected.blue, accuracy: 0.001, "\(kind) blue")
        }
    }

    func testNightColoursAreBrightenedNotReplaced() {
        // Clear night base is (20, 28, 44); saturation -0.25 and value +0.25.
        let brightened = WeatherBackdrop.backgroundColor(.clear, daylight: false)
        XCTAssertEqual(brightened.red, 76, accuracy: 1)
        XCTAssertEqual(brightened.green, 87, accuracy: 1)
        XCTAssertEqual(brightened.blue, 108, accuracy: 1)

        // Brighter means lighter, for every kind, in every channel-composite sense.
        for kind in WeatherKind.allCases {
            let base = WeatherBackdrop.baseColor(kind, daylight: false)
            let used = WeatherBackdrop.backgroundColor(kind, daylight: false)
            let baseSum = base.red + base.green + base.blue
            let usedSum = used.red + used.green + used.blue
            XCTAssertGreaterThanOrEqual(usedSum, baseSum, "\(kind) night colour got darker")
        }
    }

    func testDaylightIsReturnedUntouched() {
        for kind in WeatherKind.allCases {
            XCTAssertEqual(
                WeatherBackdrop.backgroundColor(kind, daylight: true),
                WeatherBackdrop.baseColor(kind, daylight: true)
            )
        }
    }

    func testKindMappingFollowsUpstream() {
        XCTAssertEqual(WeatherBackdrop.kind(for: .clear), .clear)
        XCTAssertEqual(WeatherBackdrop.kind(for: .partlyCloudy), .cloud)
        XCTAssertEqual(WeatherBackdrop.kind(for: .thunderstorm), .thunderstorm)
        XCTAssertEqual(WeatherBackdrop.kind(for: .sleet), .sleet)
        XCTAssertEqual(WeatherBackdrop.kind(for: .wind), .wind)
    }
}
