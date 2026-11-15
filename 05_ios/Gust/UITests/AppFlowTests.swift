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
        XCTAssertTrue(anyElement(app, "settings.appearance").exists)
    }

    func testTappingHourlyCardOpensDetail() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["header.temperature"].waitForExistence(timeout: 30))

        let link = anyElement(app, "cardLink.hourly")
        XCTAssertTrue(link.waitForExistence(timeout: 10), "hourly card is not a link")
        link.tap()

        XCTAssertTrue(anyElement(app, "detail.screen").waitForExistence(timeout: 10), "detail page did not open")
        XCTAssertTrue(anyElement(app, "hourly.row.0").exists, "hourly detail has no rows")
        // Upstream's detail header: a day selector and a day/night pair.
        XCTAssertTrue(anyElement(app, "detail.day.0").exists, "detail day selector missing")
        XCTAssertTrue(anyElement(app, "detail.daytime").exists, "daytime panel missing")
        XCTAssertTrue(anyElement(app, "detail.nighttime").exists, "nighttime panel missing")
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists, "no way back from the detail page")
    }

    func testChangingTemperatureUnitUpdatesTheMainScreen() {
        let app = launch()
        let header = app.staticTexts["header.temperature"]
        XCTAssertTrue(header.waitForExistence(timeout: 30))
        // Fresh state, Celsius by default: the unit is a separate label beside the
        // number, as upstream splits value and unit.
        XCTAssertTrue(app.staticTexts["°C"].waitForExistence(timeout: 5))
        let feelsLikeBefore = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'feels like'")
        ).firstMatch.label

        app.tabBars.buttons["Settings"].tap()
        let appearance = anyElement(app, "settings.appearance")
        XCTAssertTrue(appearance.waitForExistence(timeout: 10), "Appearance row missing")
        appearance.tap()
        let picker = anyElement(app, "settings.temperature")
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "temperature picker missing")
        picker.tap()
        app.buttons["Fahrenheit (°F)"].tap()

        app.tabBars.buttons["Weather"].tap()
        XCTAssertTrue(header.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["°F"].waitForExistence(timeout: 10), "unit beside the header did not follow the setting")

        // "Feels like" also renders through the preferences. Its number must change
        // with the unit even though it shows no unit suffix of its own.
        let feelsLike = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'feels like'")).firstMatch
        XCTAssertTrue(feelsLike.waitForExistence(timeout: 10), "feels-like line missing")
        XCTAssertNotEqual(feelsLike.label, feelsLikeBefore,
                          "feels-like value did not follow the unit change")
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
