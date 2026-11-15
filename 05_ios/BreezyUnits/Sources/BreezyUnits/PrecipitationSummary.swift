//
//  PrecipitationSummary.swift
//  BreezyUnits
//
//  Ported from `PrecipitationViewHolder.onBindView`.
//
//  Upstream does not show "today's total": it shows the half of the day you are in,
//  split at fixed hours (05:00 and 17:00, not sunrise and sunset) and named after what
//  is actually in that half — rain, snow, or a mix. The label and the number have to
//  agree, which is what this type exists to guarantee.
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

    /// Upstream's fixed split: 05:00–16:59 is day, everything else is night.
    public static func period(forHour hour: Int) -> PrecipitationPeriod {
        (5...16).contains(hour) ? .day : .night
    }

    /// The label under the value. Mixing rain and snow, or having only one of them,
    /// changes the words; an empty half still says which half it is about.
    public var label: String {
        let hasRain = rain.inMillimeters > 0
        let hasSnow = snow.inMillimeters > 0
        if hasRain && hasSnow {
            return "\(period.adjective) precipitation"
        }
        if hasSnow && snow.inMillimeters >= total.inMillimeters {
            return "\(period.adjective) snow"
        }
        if hasRain && rain.inMillimeters >= total.inMillimeters {
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

        // The local day `now` falls in: before 05:00 that is the night that started
        // yesterday evening, which is why the filter is by hour and not by calendar day.
        let dayStart = calendar.startOfDay(for: now)
        let windowStart = period == .day
            ? dayStart.addingTimeInterval(5 * 3600)
            : dayStart.addingTimeInterval(17 * 3600)
        let windowEnd = period == .day
            ? dayStart.addingTimeInterval(17 * 3600)
            : dayStart.addingTimeInterval(24 * 3600 + 5 * 3600)

        let inWindow = hourly.filter { $0.date >= windowStart && $0.date < windowEnd }
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
