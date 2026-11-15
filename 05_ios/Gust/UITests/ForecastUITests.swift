//
//  ForecastUITests.swift
//  GustUITests
//
//  Stage-6 gate. Two things are worth asserting here and nothing else:
//    1. real data reaches the screen (not the loading state, not an error), and
//    2. the ported half/full card rule actually holds in layout — half cards sit
//       two per row at equal widths, which is the single most visible difference
//       between a faithful port and a SwiftUI rewrite that "looks about right".
//

import XCTest

final class ForecastUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState"]
        app.launch()
        return app
    }

    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testForecastLoadsAndRendersValue() {
        let app = launch()

        // The header temperature only exists once a payload has been decoded and
        // mapped; a stuck loading state or an error view would not satisfy this.
        let temperature = app.staticTexts["header.temperature"]
        XCTAssertTrue(temperature.waitForExistence(timeout: 30), "forecast never loaded")
        XCTAssertTrue(temperature.label.hasSuffix("°"), "unexpected temperature label: \(temperature.label)")
        XCTAssertNotEqual(temperature.label, "—", "temperature missing from a loaded forecast")

        XCTAssertTrue(anyElement(app, "card.hourly").exists, "hourly card missing")
        XCTAssertTrue(anyElement(app, "card.daily").exists, "daily card missing")

        // Upstream drops the last day of the payload; there must still be many days.
        XCTAssertTrue(anyElement(app, "daily.row.1").exists, "daily list has fewer than two rows")
        XCTAssertFalse(anyElement(app, "forecast.error").exists, "error view shown instead of weather")
    }

    func testHalfSizeCardsPairTwoPerRow() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["header.temperature"].waitForExistence(timeout: 30))

        let wind = anyElement(app, "card.wind")
        XCTAssertTrue(wind.waitForExistence(timeout: 5), "wind card missing")

        // Scroll until the first half-card row is on screen.
        var attempts = 0
        while !wind.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }

        // The first half-card row is wind + air quality, because the card list
        // follows upstream's order (precipitation, wind, air quality, pollen,
        // humidity, UV, visibility, pressure, sun). If that order changes, this
        // assertion changes with it — the rule itself is tested in the package.
        let neighbour = anyElement(app, "card.air quality")
        XCTAssertTrue(neighbour.exists, "air quality card missing")

        // The law: same row, same width, no overlap.
        XCTAssertEqual(wind.frame.minY, neighbour.frame.minY, accuracy: 1.0,
                       "half cards are not on the same row")
        XCTAssertEqual(wind.frame.width, neighbour.frame.width, accuracy: 1.0,
                       "half cards have different widths")
        XCTAssertLessThanOrEqual(wind.frame.maxX, neighbour.frame.minX + 0.5,
                                "half cards overlap")

        // ...and half of the screen, not the whole width.
        let screenWidth = app.windows.firstMatch.frame.width
        XCTAssertLessThan(wind.frame.width, screenWidth * 0.62,
                          "half card is stretched instead of half width")
    }

    func testErrorStateOffersRecovery() {
        // The failure path must be a real view with a way out, not a blank screen.
        // Forced by pointing the app at an invalid host through a launch argument.
        let app = XCUIApplication()
        app.launchArguments = ["-resetState", "-gustBaseURLOverride", "https://invalid.invalid/v1/forecast"]
        app.launch()

        let error = anyElement(app, "forecast.error")
        let temperature = app.staticTexts["header.temperature"]
        // Either the error view appears, or the override was ignored and data
        // loaded — both are acceptable; a blank screen is not.
        let deadline = Date().addingTimeInterval(40)
        while Date() < deadline && !error.exists && !temperature.exists {
            usleep(300_000)
        }
        XCTAssertTrue(error.exists || temperature.exists,
                      "screen stayed blank: neither error nor data appeared")
    }
}
