//
//  PrecipitationSummary.swift
//  BreezyUnits
//
//  Ported from `PrecipitationViewHolder.onBindView`.
//
//  Upstream does not show "today's total": it shows the half of the day you are in and
//  names it after what is actually in that half — rain, snow, or a mix.
//
//  Two different clocks are involved and they are not the same one:
//
//  - which half is *shown* is decided at 05:00 and 17:00 (`PrecipitationViewHolder`);
//  - which hours are *summed* into a half is decided at 06:00 and 18:00
//    (`CommonConverter.getHourlyListByHalfDay`, which shifts each hour by six hours and
//    calls anything before noon "day").
//
//  They disagree between 05:00–05:59 and 17:00–17:59, and upstream lives with it, so
//  this port reproduces it rather than tidying it. What it must not do — what it did do
//  before — is look *forward* at 3 a.m.: "Nighttime" then summed tonight's 17:00–05:00,
//  i.e. hours that had not happened yet, and showed a total for a night still to come.
//

import Foundation

public enum PrecipitationPeriod: String, Sendable {
    case day, night

    public var adjective: String { self == .day ? "Daytime" : "Nighttime" }
}

public struct PrecipitationSummary: Equatable, Sendable {
    public let period: PrecipitationPeriod
    public let total: Precipitation
    public let rain: Precipitation
    public let snow: Precipitation

    public init(period: PrecipitationPeriod, total: Precipitation, rain: Precipitation, snow: Precipitation) {
        self.period = period
        self.total = total
        self.rain = rain
        self.snow = snow
    }

    /// Which half the card describes, from `PrecipitationViewHolder`: 05:00–16:59 is
    /// day, everything else is night.
    public static func period(forHour hour: Int) -> PrecipitationPeriod {
        (5...16).contains(hour) ? .day : .night
    }

    /// The hours summed into a half, from `getHourlyListByHalfDay`: 06:00–17:59 is the
    /// day, 18:00–05:59 the night that follows it. A night is attached to the evening it
    /// starts in, so at 03:00 the half being described is *yesterday* evening's night.
    public static func window(
        period: PrecipitationPeriod,
        at now: Date,
        timeZone: TimeZone
    ) -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var dayStart = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)

        switch period {
        case .day:
            return (dayStart.addingTimeInterval(6 * 3600), dayStart.addingTimeInterval(18 * 3600))
        case .night:
            // Before 06:00 the night in progress began yesterday evening.
            if hour < 6 {
                dayStart = calendar.startOfDay(for: dayStart.addingTimeInterval(-1))
            }
            return (dayStart.addingTimeInterval(18 * 3600), dayStart.addingTimeInterval(30 * 3600))
        }
    }

    /// The label under the value. Mixing rain and snow, or having only one of them,
    /// changes the words; an empty half still says which half it is about.
    public var label: String {
        let hasRain = rain.inMillimeters > 0
        let hasSnow = snow.inMillimeters > 0
        if hasRain && hasSnow {
            return "\(period.adjective) precipitation"
        }
        // Upstream tests equality, not "at least": a half whose rain and snow add up to
        // less than its total still says "precipitation".
        if hasSnow && snow.inMillimeters == total.inMillimeters {
            return "\(period.adjective) snow"
        }
        if hasRain && rain.inMillimeters == total.inMillimeters {
            return "\(period.adjective) rain"
        }
        return "\(period.adjective) precipitation"
    }

    /// Sums the hourly forecast into the period the clock is in. `now` decides which
    /// period; the hours summed are the ones inside that period on that local day.
    public static func today(
        from hourly: [HourlyForecast],
        at now: Date,
        timeZone: TimeZone
    ) -> PrecipitationSummary? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: now)
        let period = period(forHour: hour)

        let bounds = window(period: period, at: now, timeZone: timeZone)
        let inWindow = hourly.filter { $0.date >= bounds.start && $0.date < bounds.end }
        guard !inWindow.isEmpty else { return nil }

        func sum(_ keyPath: KeyPath<HourlyForecast, Precipitation?>) -> Precipitation {
            inWindow.reduce(0.0) { total, hour in
                total + (hour[keyPath: keyPath]?.inMillimeters ?? 0)
            }.millimeters
        }
        return PrecipitationSummary(
            period: period,
            total: sum(\.precipitation),
            rain: sum(\.rain),
            snow: sum(\.snow)
        )
    }
}
