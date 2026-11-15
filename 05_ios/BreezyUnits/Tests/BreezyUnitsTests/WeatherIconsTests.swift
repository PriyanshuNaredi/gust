//
//  WeatherIconsTests.swift
//  BreezyUnitsTests
//
//  Upstream's icon names are built by string concatenation and resolved through a
//  filter, so a typo produces a blank space rather than an error. These tests check
//  the concatenation *and* that every name has a file in the app's resource folder,
//  which is the only way that class of defect shows up before a screenshot.
//

import XCTest
@testable import BreezyUnits

final class WeatherIconsTests: XCTestCase {
    func testDayAndNightSplitOnlyWhereArtworkSplits() {
        XCTAssertEqual(WeatherIcons.name(for: .clear, day: true), "weather_clear_day")
        XCTAssertEqual(WeatherIcons.name(for: .clear, day: false), "weather_clear_night")
        XCTAssertEqual(WeatherIcons.name(for: .partlyCloudy, day: false), "weather_partly_cloudy_night")
        // Shared artwork: the suffix would resolve to nothing, which is what the
        // Android filter exists to hide.
        for code in [WeatherCode.cloudy, .rain, .snow, .wind, .fog, .haze, .sleet, .hail, .thunder, .thunderstorm] {
            XCTAssertEqual(WeatherIcons.name(for: code, day: true), WeatherIcons.name(for: code, day: false))
            XCTAssertFalse(WeatherIcons.name(for: code, day: true).hasSuffix("_day"))
        }
    }

    func testMiniNamesCarryTheirStyle() {
        XCTAssertEqual(WeatherIcons.miniName(for: .rain, day: true, style: .dark), "weather_rain_mini_dark")
        XCTAssertEqual(WeatherIcons.miniName(for: .clear, day: false, style: .light), "weather_clear_night_mini_light")
    }

    /// The bundle check. Resolves `Resources/WeatherIcons` from this file's path, so
    /// it works under `swift test`, Xcode and CI alike.
    func testEveryNameHasArtwork() throws {
        let here = URL(fileURLWithPath: #filePath)
        let resources = here
            .deletingLastPathComponent()   // BreezyUnitsTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // BreezyUnits
            .deletingLastPathComponent()   // 05_ios
            .appendingPathComponent("Gust/Resources/WeatherIcons")

        XCTAssertTrue(FileManager.default.fileExists(atPath: resources.path), "no icon folder at \(resources.path)")

        let names = WeatherIcons.allNames
        XCTAssertGreaterThan(names.count, 10)
        for name in names {
            let file = resources.appendingPathComponent("\(name).png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "missing artwork: \(name).png")
        }
    }
}
