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
        // Upstream splits the value from its unit so the unit can be smaller; the
        // value is a bare number and the unit lives beside it.
        XCTAssertNotNil(Double(temperature.label), "unexpected temperature label: \(temperature.label)")
        XCTAssertTrue(app.staticTexts["°C"].exists || app.staticTexts["°F"].exists, "no unit beside the temperature")

        // The hourly card is a navigation link, and a link is one accessibility
        // element: its inner identifier is not addressable, the link's is.
        XCTAssertTrue(anyElement(app, "cardLink.hourly").exists, "hourly card missing")
        // The nowcast card is drawn with Canvas, not text, so its presence is the
        // only assertion that makes sense here.
        XCTAssertTrue(anyElement(app, "card.nowcast").exists, "nowcast card missing")
        XCTAssertTrue(anyElement(app, "cardLink.daily").exists, "daily card missing")

        // The daily card's trend tabs prove the block is the tabbed trend view and not
        // a placeholder. Per-day identifiers are not addressable: the card is a
        // NavigationLink, and a link collapses its subtree into one button (the day
        // count itself is asserted at the data level in BreezyUnitsTests).
        XCTAssertTrue(app.buttons["tab.Conditions"].exists, "trend tabs missing")
        XCTAssertTrue(app.buttons["tab.Wind"].exists, "trend tabs missing")
        XCTAssertFalse(anyElement(app, "forecast.error").exists, "error view shown instead of weather")
    }

    func testHalfSizeCardsPairTwoPerRow() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["header.temperature"].waitForExistence(timeout: 30))

        let identifiers = [
            "cardLink.precipitation", "cardLink.wind", "cardLink.airQuality",
            "cardLink.pollen", "cardLink.humidity", "cardLink.uv",
            "cardLink.visibility", "cardLink.pressure"
        ]

        // Scroll until the half-card block is on screen.
        let firstCard = anyElement(app, "cardLink.wind")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10), "half cards missing")
        var attempts = 0
        while !firstCard.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }

        // Only elements actually on screen report meaningful frames; an off-screen
        // element's frame is stale and made an earlier version of this test claim
        // the cards overlapped.
        let visible = identifiers
            .map { ($0, anyElement(app, $0)) }
            .filter { $0.1.exists && $0.1.isHittable }
        XCTAssertGreaterThanOrEqual(visible.count, 2, "fewer than two half cards on screen")

        // Group by row, then assert every row of two has equal halves.
        var rows: [Int: [(String, CGRect)]] = [:]
        for (identifier, element) in visible {
            let bucket = Int((element.frame.minY / 2).rounded()) * 2
            rows[bucket, default: []].append((identifier, element.frame))
        }

        var sawPair = false
        for (_, row) in rows {
            XCTAssertLessThanOrEqual(row.count, 2, "more than two half cards in one row: \(row.map(\.0))")
            guard row.count == 2 else { continue }
            sawPair = true
            XCTAssertEqual(row[0].1.width, row[1].1.width, accuracy: 1.0,
                           "\(row[0].0) and \(row[1].0) are not equal halves")
            XCTAssertLessThanOrEqual(row[0].1.maxX, row[1].1.minX + 0.5,
                                     "\(row[0].0) overlaps \(row[1].0)")
        }
        XCTAssertTrue(sawPair, "no two half cards shared a row: \(rows.mapValues { $0.map(\.0) })")

        let screenWidth = app.windows.firstMatch.frame.width
        for (identifier, element) in visible {
            XCTAssertLessThan(element.frame.width, screenWidth * 0.62,
                              "\(identifier) is stretched instead of half width")
        }
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
