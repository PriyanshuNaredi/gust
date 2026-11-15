//
//  LocalTimeTests.swift
//  GustUITests
//
//  Times must be shown in the location's zone, not the device's. Berlin sunrise in
//  November is around 07:00 — never around 01:00, whatever the simulator is set to.
//

import XCTest

final class LocalTimeTests: XCTestCase {
    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func testSunriseIsShownInTheLocationZone() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetState"]
        app.launch()
        XCTAssertTrue(app.staticTexts["header.temperature"].waitForExistence(timeout: 30))

        let sun = anyElement(app, "card.sun")
        var attempts = 0
        while !sun.isHittable && attempts < 8 { app.swipeUp(); attempts += 1 }
        XCTAssertTrue(sun.exists, "sun card missing")

        // A container element has no label of its own, so read its text children.
        let text = sun.descendants(matching: .staticText).allElementsBoundByIndex
            .map(\.label)
            .joined(separator: " ")
        XCTAssertFalse(text.isEmpty, "sun card has no text")

        let firstHour = firstHourIn(text)
        XCTAssertNotNil(firstHour, "no time found in sun card: \(text)")
        if let firstHour {
            // Sunrise in Berlin is between 03:00 and 09:00 all year; anything outside
            // that means the time was formatted in another zone.
            XCTAssertTrue((3...9).contains(firstHour),
                          "sunrise \(firstHour)h looks like a device-zone time: \(text)")
        }
    }

    /// First "H:MM" hour plus the AM/PM that belongs to *that* time. Looking for
    /// "PM" anywhere in the label picks up the sunset and turns 07:26 into 19:26.
    private func firstHourIn(_ label: String) -> Int? {
        let pattern = try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})\\s*([AP]M)?")
        let range = NSRange(label.startIndex..., in: label)
        guard let match = pattern?.firstMatch(in: label, range: range),
              let hourRange = Range(match.range(at: 1), in: label) else { return nil }
        var hour = Int(label[hourRange]) ?? -1
        let meridiem = Range(match.range(at: 3), in: label).map { String(label[$0]) }
        if meridiem == "PM", hour < 12 { hour += 12 }
        if meridiem == "AM", hour == 12 { hour = 0 }
        return hour
    }
}
