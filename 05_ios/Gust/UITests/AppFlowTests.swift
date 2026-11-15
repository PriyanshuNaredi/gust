//
//  AppFlowTests.swift
//  GustUITests
//
//  The journeys a user actually takes: switch tab, open a detail page, change a
//  unit and see the main screen follow, search for a place. Each one asserts an
//  outcome, not a tap.
//

import XCTest

final class AppFlowTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState"]
        app.launch()
        return app
    }

    private func anyElement(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testTabsArePresentAndSwitch() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["header.temperature"].waitForExistence(timeout: 30))

        app.tabBars.buttons["Locations"].tap()
        XCTAssertTrue(app.navigationBars["Locations"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Berlin"].exists)

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement(app, "settings.temperature").exists)
    }

    func testTappingHourlyCardOpensDetail() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["header.temperature"].waitForExistence(timeout: 30))

        let link = anyElement(app, "cardLink.hourly")
        XCTAssertTrue(link.waitForExistence(timeout: 10), "hourly card is not a link")
        link.tap()

        XCTAssertTrue(anyElement(app, "detail.screen").waitForExistence(timeout: 10), "detail page did not open")
        XCTAssertTrue(anyElement(app, "hourly.row.0").exists, "hourly detail has no rows")
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "no way back from the detail page")
    }

    func testChangingTemperatureUnitUpdatesTheMainScreen() {
        let app = launch()
        let header = app.staticTexts["header.temperature"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        // Celsius by default.
        XCTAssertTrue(header.label.hasSuffix("°"))

        app.tabBars.buttons["Settings"].tap()
        let picker = anyElement(app, "settings.temperature")
        XCTAssertTrue(picker.exists, "temperature picker missing")
        picker.tap()
        app.buttons["Fahrenheit (°F)"].tap()

        app.tabBars.buttons["Weather"].tap()
        XCTAssertTrue(header.waitForExistence(timeout: 15))

        // "Feels like" renders through the preferences, so it carries the unit
        // suffix the header omits; this is the assertion that proves the setting
        // reached the main screen.
        let feelsLike = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'feels like'")).firstMatch
        XCTAssertTrue(feelsLike.waitForExistence(timeout: 10), "feels-like line missing")
        XCTAssertTrue(feelsLike.label.hasSuffix("°F"),
                      "unit change did not reach the main screen: \(feelsLike.label)")
    }

    func testSearchFindsAPlaceAndAddsIt() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["header.temperature"].waitForExistence(timeout: 30))

        app.tabBars.buttons["Locations"].tap()
        anyElement(app, "locations.add").tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "search field missing")
        field.tap()
        field.typeText("Paris")

        // The service is live here, so wait rather than assume.
        let paris = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'searchResult.'"))
            .firstMatch
        XCTAssertTrue(paris.waitForExistence(timeout: 20), "no search results appeared")
        paris.tap()

        XCTAssertTrue(app.navigationBars["Locations"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Paris"].waitForExistence(timeout: 10), "added place not listed")

        // The forecast must follow the selection.
        app.tabBars.buttons["Weather"].tap()
        XCTAssertTrue(app.staticTexts["Paris"].waitForExistence(timeout: 30), "main screen did not switch place")
    }
}
