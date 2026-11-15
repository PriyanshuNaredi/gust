//
//  NowcastChartTests.swift
//  BreezyUnitsTests
//
//  The nowcast card's two sentences and its chart law, pinned to the upstream source:
//  `Weather.getMinutelyTitle`/`getMinutelyDescription` and `PrecipitationNowcastViewHolder`.
//

import Foundation
import Testing
@testable import BreezyUnits

@Suite("Nowcast chart")
struct NowcastChartTests {
    /// 2026-06-01 12:00 UTC, then one step every 15 minutes.
    private let start = Date(timeIntervalSince1970: 1_780_315_200)
    private let berlin = TimeZone(identifier: "Europe/Berlin")!
    private let english = Locale(identifier: "en_GB")

    /// `rain` is one accumulation in millimetres per 15-minute step; `nil` is a dry step.
    private func nowcast(_ rain: [Double?]) -> Nowcast {
        Nowcast(steps: rain.enumerated().map { index, millimeters in
            MinutelyForecast(
                date: start.addingTimeInterval(Double(index) * 900),
                precipitation: millimeters.map { Precipitation(referenceValue: Int64(($0 * 1000).rounded())) }
            )
        })
    }

    @Test("a 15-minute accumulation becomes an hourly rate")
    func rateConversion() {
        // 3 mm in 15 minutes is 12 mm/h. Comparing 3 against the 5/10/15 thresholds
        // directly would call a downpour "light".
        let rates = nowcast([3, nil, 1.25]).rates
        #expect(abs(rates[0].millimetersPerHour - 12) < 0.0001)
        #expect(abs(rates[1].millimetersPerHour) < 0.0001)
        #expect(abs(rates[2].millimetersPerHour - 5) < 0.0001)
    }

    @Test("the chart is 24 five-minute buckets over two hours")
    func bucketCount() {
        let buckets = nowcast(Array(repeating: nil, count: 12)).chartRates()
        #expect(buckets.count == 24)
        #expect(buckets[1].date.timeIntervalSince(buckets[0].date) == 300)
        #expect(buckets[23].date.timeIntervalSince(buckets[0].date) == 23 * 300)
    }

    @Test("three buckets per 15-minute source step, all carrying the same rate")
    func resampling() {
        let buckets = nowcast([4, nil, nil, nil]).chartRates()
        #expect(buckets.prefix(3).allSatisfy { abs($0.millimetersPerHour - 16) < 0.0001 })
        #expect(buckets.dropFirst(3).prefix(3).allSatisfy { $0.millimetersPerHour == 0 })
    }

    @Test("the axis tops out at max(heavy, wettest bucket)")
    func chartMaximum() {
        #expect(nowcast(Array(repeating: nil, count: 4)).chartMaximum == 15)
        #expect(nowcast([6, nil, nil, nil]).chartMaximum == 24)
    }

    @Test("threshold lines drop out as the maximum grows")
    func thresholdLaw() {
        // Below heavy + heavy: all three, because they are all reachable.
        #expect(Nowcast.thresholds(maximum: 15).map(\.label) == ["Light", "Medium", "Heavy"])
        // Between heavy and twice heavy: the medium label would overlap the heavy one.
        #expect(Nowcast.thresholds(maximum: 20).map(\.label) == ["Light", "Heavy"])
        // Above twice heavy: only heavy survives.
        #expect(Nowcast.thresholds(maximum: 30).map(\.label) == ["Heavy"])
        #expect(Nowcast.thresholds(maximum: 80).map(\.label) == ["Heavy"])
        #expect(Nowcast.thresholds(maximum: 80).first?.millimetersPerHour == 15)
    }

    @Test("dry throughout: the title and the description disagree, as upstream's do")
    func dryCopy() {
        let dry = nowcast([nil, nil, nil, nil])
        #expect(dry.state == .none)
        #expect(dry.title == "Precipitation")
        #expect(dry.summary(zone: berlin, locale: english) == "No precipitation")
    }

    @Test("a dry window under a rainy sky says so")
    func dryWindowUnderRainySky() {
        let dry = nowcast([nil, nil, nil, nil])
        // Upstream's own string, unchanged, when the observation agrees.
        #expect(dry.summary(zone: berlin, locale: english) == "No precipitation")
        // The observation says "slight rain" but every measured field is 0.0 mm: the
        // card must not leave the user asking whether it is raining or not.
        #expect(dry.summary(zone: berlin, locale: english, currentIsWet: true)
            == "No precipitation expected in the next 2 hours")
        // A wet window keeps upstream's sentence whatever the observation says.
        let wet = nowcast([nil, 2, 2, nil])
        #expect(wet.summary(zone: berlin, locale: english, currentIsWet: true)
            == "Expected to start at 14:15")
    }

    @Test("the observation is wet exactly for the precipitation families")
    func wetObservation() {
        func weather(_ code: WeatherCode?) -> Weather {
            Weather(current: CurrentObservation(date: start, weatherCode: code),
                    hourlyForecast: [], dailyForecast: [], minutelyForecast: [], refreshTime: start)
        }
        #expect(weather(.rain).currentIsWet)
        #expect(weather(.snow).currentIsWet)
        #expect(weather(.thunderstorm).currentIsWet)
        #expect(!weather(.cloudy).currentIsWet)
        #expect(!weather(.clear).currentIsWet)
        #expect(!weather(nil).currentIsWet)
    }

    @Test("starting, continuing and stopping read differently")
    func copy() {
        let starting = nowcast([nil, 2, 2, nil])
        #expect(starting.state == .starting)
        #expect(starting.title == "Precipitation soon")
        // Berlin in June is UTC+2: 12:15 UTC is 14:15 local.
        #expect(starting.summary(zone: berlin, locale: english) == "Expected to start at 14:15")

        let continuing = nowcast([2, 2, 2, 2])
        #expect(continuing.state == .continuing)
        #expect(continuing.title == "Precipitation")
        #expect(continuing.summary(zone: berlin, locale: english) == "Expected to continue until at least 15:00")

        let stopping = nowcast([2, 2, nil, nil])
        #expect(stopping.state == .stopping)
        #expect(stopping.title == "Precipitation stopping soon")
        #expect(stopping.summary(zone: berlin, locale: english) == "Expected to stop at 14:30")
    }

    @Test("the wet spell ends one step after its last wet step")
    func spellEnd() {
        // A 15-minute step covering 14:30–14:45 ends at 14:45, not at 14:30.
        let stopping = nowcast([2, 2, nil, nil])
        #expect(stopping.wetSpellEnd?.timeIntervalSince(stopping.lastWetDate!) == 900)
    }


    @Test("past steps are dropped, so the laws answer about now")
    func relativeToNow() {
        // It is raining at 12:00 and 12:15, then dry, then raining again from 13:00.
        // It is now 12:30: the first step (which ends at 12:30) is over, so the card
        // must read "starting", not "continuing".
        let series = nowcast([2, 2, nil, nil, 2, 2])
        #expect(series.state == .continuing)
        let now = start.addingTimeInterval(1800)
        let trimmed = series.relative(to: now)
        #expect(trimmed.steps.count == 4)
        #expect(trimmed.steps.first?.date == start.addingTimeInterval(1800))
        #expect(trimmed.state == .starting)
        // The chart, likewise, begins at the first step that has not ended.
        #expect(series.chartRates(from: now).first?.date == start.addingTimeInterval(1800))
        #expect(series.chartRates().first?.date == start)
    }

    @Test("a series entirely in the past keeps its last step rather than going empty")
    func fullyPast() {
        let series = nowcast([2, 2, 2])
        let trimmed = series.relative(to: start.addingTimeInterval(86_400))
        #expect(trimmed.steps.count == 1)
        #expect(trimmed.steps.first?.date == start.addingTimeInterval(1800))
    }

    @Test("rain beyond the chart's own span is not announced by the card")
    func outsideSpan() {
        // Dry for the next two hours, wet eight hours later, as Open-Meteo's next-day
        // tail does at 02:15. The card must not claim "Precipitation soon" over an
        // empty chart: it describes this window or nothing.
        var rain: [Double?] = Array(repeating: nil, count: 4)
        rain += Array(repeating: 2, count: 4)
        let series = Nowcast(steps: rain.enumerated().map { index, millimeters in
            MinutelyForecast(
                date: start.addingTimeInterval(Double(index) * 1800),
                precipitation: millimeters.map { Precipitation(referenceValue: Int64($0 * 1000)) }
            )
        })
        let now = start
        let clipped = series.relative(to: now)
        // Only the four steps inside two hours survive.
        #expect(clipped.steps.count == 4)
        #expect(clipped.state == .none)
        #expect(clipped.title == "Precipitation")
        #expect(clipped.summary(zone: berlin, locale: english) == "No precipitation")
    }

    @Test("times are formatted in the location's zone, not the device's")
    func zoneFormatting() {
        let moment = Date(timeIntervalSince1970: 1_780_315_200) // 12:00 UTC
        #expect(Nowcast.time(moment, zone: berlin, locale: english) == "14:00")
        #expect(Nowcast.time(moment, zone: TimeZone(identifier: "America/New_York")!, locale: english) == "08:00")
    }
}
