//
//  NowcastChart.swift
//  BreezyUnits
//
//  What the nowcast card *says* and *charts*, ported from the upstream holder:
//  `PrecipitationNowcastViewHolder.kt` (5-minute buckets, the three-tick time axis, the
//  intensity threshold lines and the rule for which of them survive a downpour) and
//  `Weather.getMinutelyTitle` / `getMinutelyDescription` (the two strings).
//
//  Unchanged from upstream, and asserted in `NowcastChartTests`:
//  - the chart is drawn in **5-minute** buckets, whatever the source interval is;
//  - the y-axis tops out at `max(heavy, wettest bucket)`, never normalised;
//  - the threshold lines are at 5 / 10 / 15 mm/h, and above 2 × heavy only heavy
//    survives, because three labels over a downpour's bar are unreadable;
//  - the title and the description are two different sentences.
//
//  DEVIATION 27: the chart spans two hours (24 buckets) rather than the whole minutely
//  series. Open-Meteo's minutely series runs for days; upstream's own radar providers
//  send two hours. Charting days would put one bucket per pixel.
//

import Foundation

/// One chart bucket: a moment and the rain rate that applies from it.
public struct NowcastRate: Hashable, Sendable {
    public let date: Date
    /// Millimetres per hour, which is the unit the 5/10/15 thresholds are written in.
    public let millimetersPerHour: Double

    public init(date: Date, millimetersPerHour: Double) {
        self.date = date
        self.millimetersPerHour = millimetersPerHour
    }
}

/// One labelled horizontal line across the chart.
public struct NowcastThreshold: Hashable, Sendable {
    public let millimetersPerHour: Double
    public let label: String

    public init(millimetersPerHour: Double, label: String) {
        self.millimetersPerHour = millimetersPerHour
        self.label = label
    }
}

extension Nowcast {
    /// Upstream's constants, from `Precipitation.Companion`.
    public static let hourlyLight = 5.0
    public static let hourlyMedium = 10.0
    public static let hourlyHeavy = 15.0
    /// The chart's bucket width and span (see DEVIATION 27 above).
    public static let bucketSeconds: TimeInterval = 5 * 60
    public static let spanSeconds: TimeInterval = 2 * 60 * 60

    /// The series as seen *now*, clipped to the chart's own span.
    ///
    /// Upstream's minutely list begins at the moment it was fetched and runs for about
    /// two hours; Open-Meteo's begins at local midnight and runs for days. Applying the
    /// title law to the whole series therefore answered a question about some other
    /// hour: here it read "Precipitation soon — expected to start at 02:15" over a chart
    /// of the next two hours with nothing in it, because 02:15 was the following night.
    ///
    /// Clipping to the span has a second property worth stating: the sentence and the
    /// chart can never disagree, because both describe the same two hours.
    public func relative(to now: Date, span: TimeInterval = Nowcast.spanSeconds) -> Nowcast {
        let interval = stepInterval
        let horizon = now.addingTimeInterval(span)
        let inWindow = steps.filter {
            $0.date.addingTimeInterval(interval) > now && $0.date < horizon
        }
        // Nothing in the window (a dry day, or a source that ended): keep one step so
        // the card still renders its axis and says "No precipitation".
        return Nowcast(steps: inWindow.isEmpty ? [steps.last].compactMap { $0 } : inWindow)
    }

    /// Rate for every source step. Pure accumulation × 3600 / interval, so a 15-minute
    /// source and a 5-minute source produce the same rate for the same weather.
    public var rates: [NowcastRate] {
        let interval = stepInterval
        return steps.map {
            NowcastRate(
                date: $0.date,
                millimetersPerHour: Nowcast.millimetersPerHour(of: $0, suggesting: interval)
            )
        }
    }

    /// The chart series: one bucket per five minutes, over `span` from the first step.
    /// A bucket takes the rate of the source step that covers it, so a 15-minute source
    /// produces three equal buckets rather than three copies of an accumulation.
    public func chartRates(from now: Date = .distantPast,
                           span: TimeInterval = Nowcast.spanSeconds) -> [NowcastRate] {
        let interval = stepInterval
        let startIndex = steps.firstIndex { $0.date.addingTimeInterval(interval) > now } ?? 0
        guard startIndex < steps.count else { return [] }
        let first = steps[startIndex]
        let bucketCount = Int((span / Nowcast.bucketSeconds).rounded())
        return (0..<bucketCount).map { index in
            let bucketDate = first.date.addingTimeInterval(Double(index) * Nowcast.bucketSeconds)
            let stepIndex = min(
                max(startIndex + Int(bucketDate.timeIntervalSince(first.date) / max(interval, 1)), startIndex),
                steps.count - 1
            )
            return NowcastRate(
                date: bucketDate,
                millimetersPerHour: Nowcast.millimetersPerHour(
                    of: steps[stepIndex], suggesting: interval
                )
            )
        }
    }

    /// Upstream: `max(PRECIPITATION_HOURLY_HEAVY, wettest bucket as mm/h)`.
    public var chartMaximum: Double {
        max(Nowcast.hourlyHeavy, chartRates().map(\.millimetersPerHour).max() ?? 0)
    }

    /// Which threshold lines survive. Three over a downpour is unreadable, so the light
    /// and medium labels drop out as the maximum grows. Order is light, medium, heavy.
    public static func thresholds(maximum: Double) -> [NowcastThreshold] {
        var lines: [NowcastThreshold] = []
        if maximum < hourlyHeavy * 2 {
            lines.append(NowcastThreshold(millimetersPerHour: hourlyLight, label: "Light"))
        }
        if maximum <= hourlyHeavy {
            lines.append(NowcastThreshold(millimetersPerHour: hourlyMedium, label: "Medium"))
        }
        lines.append(NowcastThreshold(millimetersPerHour: hourlyHeavy, label: "Heavy"))
        return lines
    }

    // MARK: - The two sentences

    /// `getMinutelyTitle`: "Precipitation soon", "Precipitation", "Precipitation
    /// stopping soon".
    public var title: String {
        switch state {
        case .starting: return "Precipitation soon"
        case .continuing: return "Precipitation"
        case .stopping: return "Precipitation stopping soon"
        case .none: return "Precipitation"
        }
    }

    /// `getMinutelyDescription`: when it starts, how long it lasts, when it stops. The
    /// wet spell's *end* is the last wet step plus one step, not the last step's start.
    public func summary(zone: TimeZone, locale: Locale = .current) -> String {
        switch state {
        case .starting:
            guard let start = firstWetDate else { return Self.noPrecipitation }
            return "Expected to start at " + Self.time(start, zone: zone, locale: locale)
        case .continuing:
            guard let end = wetSpellEnd else { return Self.noPrecipitation }
            return "Expected to continue until at least " + Self.time(end, zone: zone, locale: locale)
        case .stopping:
            guard let end = wetSpellEnd else { return Self.noPrecipitation }
            return "Expected to stop at " + Self.time(end, zone: zone, locale: locale)
        case .none:
            return Self.noPrecipitation
        }
    }

    public static let noPrecipitation = "No precipitation"

    /// The last wet step's end: its start plus one step interval.
    public var wetSpellEnd: Date? {
        lastWetDate?.addingTimeInterval(stepInterval)
    }

    /// Locale-aware clock time. Upstream honours the device's 12/24-hour setting, so the
    /// formatter is locale-driven rather than a hardcoded "HH:mm".
    public static func time(_ date: Date, zone: TimeZone, locale: Locale = .current) -> String {
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = zone
        style.locale = locale
        return date.formatted(style)
    }
}
