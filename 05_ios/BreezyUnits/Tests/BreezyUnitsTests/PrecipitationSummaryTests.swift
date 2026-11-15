//
//  PrecipitationSummaryTests.swift
//  BreezyUnits
//
//  The card's label and its number must describe the same half of the day.
//

import XCTest
@testable import BreezyUnits

final class PrecipitationSummaryTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Berlin")!
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ hour: Int, day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: 30))!
    }

    private func hours() -> [HourlyForecast] {
        (0..<48).map { offset in
            let day = offset < 24 ? 15 : 16
            let hour = offset % 24
            return HourlyForecast(
                date: date(hour, day: day),
                precipitation: (hour % 6 == 0 ? 2.0 : 0.0).millimeters,
                rain: (hour % 6 == 0 ? 2.0 : 0.0).millimeters,
                snow: (hour == 3 || hour == 21 ? 1.0 : 0.0).millimeters
            )
        }
    }

    func testSplitHoursAreUpstreamsFiveToSeventeen() {
        XCTAssertEqual(PrecipitationSummary.period(forHour: 4), .night)
        XCTAssertEqual(PrecipitationSummary.period(forHour: 5), .day)
        XCTAssertEqual(PrecipitationSummary.period(forHour: 16), .day)
        XCTAssertEqual(PrecipitationSummary.period(forHour: 17), .night)
        XCTAssertEqual(PrecipitationSummary.period(forHour: 0), .night)
    }

    func testAfternoonSumsOnlyDaytimeHours() {
        let summary = PrecipitationSummary.today(from: hours(), at: date(14), timeZone: zone)
        XCTAssertEqual(summary?.period, .day)
        // Daytime window is 05:00 up to but not including 17:00, so the hours with
        // precipitation are 06:00 and 12:00 -> 4 mm. The 18:00 value is outside it.
        XCTAssertEqual(summary?.total.inMillimeters ?? -1, 4, accuracy: 0.001)
    }

    func testEveningUsesNightHoursAndSaysSo() {
        let summary = PrecipitationSummary.today(from: hours(), at: date(20), timeZone: zone)
        XCTAssertEqual(summary?.period, .night)
        XCTAssertEqual(summary?.label, "Nighttime precipitation")
        // Night window from 17:00 to 05:00 the next morning: 18:00 (2 mm) and 00:00
        // (2 mm), and the 21:00 hour carries 1 mm of snow inside its 2 mm. Mixed
        // rain and snow, so the label stays the general one -- the words follow the
        // data, which is the whole point of this type.
        XCTAssertEqual(summary?.total.inMillimeters ?? -1, 4, accuracy: 0.001)
        XCTAssertEqual(summary?.label, "Nighttime precipitation")
    }

    func testLabelSaysSnowWhenItIsAllSnow() {
        let snowOnly = (0..<24).map { hour in
            HourlyForecast(
                date: date(hour),
                precipitation: (hour == 10 ? 3.0 : 0.0).millimeters,
                rain: 0.0.millimeters,
                snow: (hour == 10 ? 3.0 : 0.0).millimeters
            )
        }
        let summary = PrecipitationSummary.today(from: snowOnly, at: date(12), timeZone: zone)
        XCTAssertEqual(summary?.label, "Daytime snow")
        XCTAssertEqual(summary?.total.inMillimeters ?? -1, 3, accuracy: 0.001)
    }

    func testNoHoursInTheWindowMeansNoSummary() {
        XCTAssertNil(PrecipitationSummary.today(from: [], at: date(12), timeZone: zone))
    }
}
