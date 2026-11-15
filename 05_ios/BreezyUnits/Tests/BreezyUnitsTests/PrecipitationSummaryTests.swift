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

    private func date(_ hour: Int, minute: Int = 30, day: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
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

    /// Which half is *shown* is decided at 05:00 and 17:00, not at the 06:00/18:00 of
    /// the summed windows. Upstream has both, and they disagree for two hours a day.
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
        // The summed window is 06:00 up to but not including 18:00
        // (`getHourlyListByHalfDay`), so the wet hours are 06:00 and 12:00 -> 4 mm.
        // The 18:00 value belongs to the night.
        XCTAssertEqual(summary?.total.inMillimeters ?? -1, 4, accuracy: 0.001)
    }

    /// The defect this pins: at 3 a.m. the old window ran from 17:00 *that* evening to
    /// 05:00 the next morning — hours that had not happened — so the card showed a dash
    /// for a night still to come instead of the night just gone.
    func testEarlyMorningUsesTheNightThatEnded() {
        let summary = PrecipitationSummary.today(from: hours(), at: date(3, day: 16), timeZone: zone)
        XCTAssertEqual(summary?.period, .night)
        // 15th 18:00–16th 06:00: 18:00 and the 16th's 00:00 -> 4 mm.
        XCTAssertEqual(summary?.total.inMillimeters ?? -1, 4, accuracy: 0.001)
    }

    func testWindowBoundariesAreSixAndEighteen() {
        let day = PrecipitationSummary.window(period: .day, at: date(14), timeZone: zone)
        XCTAssertEqual(day.start, date(6, minute: 0))
        XCTAssertEqual(day.end, date(18, minute: 0))

        // An evening belongs to the night that follows it, whether it is 20:00 today
        // or 03:00 tomorrow.
        let evening = PrecipitationSummary.window(period: .night, at: date(20), timeZone: zone)
        XCTAssertEqual(evening.start, date(18, minute: 0))
        XCTAssertEqual(evening.end, date(6, minute: 0, day: 16))
        let smallHours = PrecipitationSummary.window(period: .night, at: date(3, day: 16), timeZone: zone)
        XCTAssertEqual(smallHours.start, date(18, minute: 0))
        XCTAssertEqual(smallHours.end, date(6, minute: 0, day: 16))
    }

    /// Upstream compares the parts to the total with `==`, not "at least": a half where
    /// neither rain nor snow accounts for the whole total stays "precipitation".
    func testPartialRainKeepsTheGeneralLabel() {
        let partial = (0..<24).map { hour in
            HourlyForecast(
                date: date(hour),
                precipitation: (hour == 10 ? 5.0 : 0.0).millimeters,
                rain: (hour == 10 ? 3.0 : 0.0).millimeters,
                snow: (hour == 10 ? 1.0 : 0.0).millimeters
            )
        }
        let summary = PrecipitationSummary.today(from: partial, at: date(12), timeZone: zone)
        XCTAssertEqual(summary?.label, "Daytime precipitation")
    }

    func testEveningUsesNightHoursAndSaysSo() {
        let summary = PrecipitationSummary.today(from: hours(), at: date(20), timeZone: zone)
        XCTAssertEqual(summary?.period, .night)
        XCTAssertEqual(summary?.label, "Nighttime precipitation")
        // Night window 18:00 to 06:00 the next morning: 18:00 (2 mm) and 00:00 (2 mm),
        // and the 21:00 and 03:00 hours carry snow. Mixed, so the label stays the
        // general one -- the words follow the data, which is the point of this type.
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
