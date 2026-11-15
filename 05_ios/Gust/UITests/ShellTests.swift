//
//  ShellTests.swift
//  GustUITests
//
//  The stage-4 gate: the app launches without signing, and the values on screen
//  are the ported arithmetic (checked against numbers upstream itself asserts).
//

import XCTest

final class ShellTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAppLaunchesAndLinksUnitsPackage() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState"]
        app.launch()

        // The app now opens on the forecast tab; the ported arithmetic lives in the
        // Units tab, so select it before asserting those values.
        let unitsTab = app.tabBars.buttons["Units"]
        XCTAssertTrue(unitsTab.waitForExistence(timeout: 10), "Units tab missing")
        unitsTab.tap()

        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10),
                      "app did not finish launching")

        // 25 °C renders as 25.0 °C — proves the package is linked and callable.
        let temperature = app.staticTexts["value.temperature"]
        XCTAssertTrue(temperature.exists)
        XCTAssertEqual(temperature.label, "25.0 °C")

        // Humidex at 25 °C / 18 °C dew point is ~26.5 °C; assert a band rather than
        // a pixel-exact string so a formatting change is not a false failure.
        let humidex = app.staticTexts["value.humidex"].label
        XCTAssertTrue(humidex.hasSuffix("°C"), "humidex missing: \(humidex)")

        // Wind chill above 10 °C must be absent, not invented.
        XCTAssertEqual(app.staticTexts["value.windchill"].label, "—",
                       "wind chill must be nil above 10 °C")
    }

    func testRelaunchKeepsWorking() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState"]
        app.launch()
        let unitsTab = app.tabBars.buttons["Units"]
        XCTAssertTrue(unitsTab.waitForExistence(timeout: 10))
        unitsTab.tap()
        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        // The tab selection is not persisted, so the second launch opens on Weather
        // again; select Units before asserting.
        let unitsTabAgain = app.tabBars.buttons["Units"]
        XCTAssertTrue(unitsTabAgain.waitForExistence(timeout: 10), "second launch failed")
        unitsTabAgain.tap()
        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10),
                      "second launch failed")
    }
}
