//
//  Nowcast.swift
//  BreezyUnits
//
//  The 15-minute precipitation nowcast, ported from
//  `domain/.../model/Weather.kt`: `hasMinutelyPrecipitation` and the three-case
//  "starting / continuing / stopping" law behind the card title.
//
//  Upstream reads `dbz` (radar reflectivity) because its own sources carry it;
//  Open-Meteo sends millimetres, so this port works from intensity. The law is the
//  same: look at the first and last steps, not at the middle.
//

import Foundation

public enum NowcastState: Sendable, Equatable {
    /// Dry now, rain later in the window.
    case starting
    /// Wet now and still wet at the end of the window.
    case continuing
    /// Wet now, dry by the end.
    case stopping
    /// Dry throughout.
    case none
}

public struct Nowcast: Sendable, Equatable {
    public let steps: [MinutelyForecast]

    public init(steps: [MinutelyForecast]) {
        self.steps = steps
    }

    private func isWet(_ step: MinutelyForecast) -> Bool {
        (step.precipitation?.inMillimeters ?? 0) > 0
    }

    public var hasPrecipitation: Bool {
        steps.contains { isWet($0) }
    }

    /// First and last wet step, for "rain starting at 14:20" phrasing.
    public var firstWetDate: Date? {
        steps.first { isWet($0) }?.date
    }

    public var lastWetDate: Date? {
        steps.last { isWet($0) }?.date
    }

    /// Upstream's case law, verbatim in effect: the first step decides whether this
    /// is "rain coming", and the last step decides whether it is also going away.
    /// A wet middle with dry edges is deliberately *not* its own state.
    public var state: NowcastState {
        guard hasPrecipitation, let first = steps.first, let last = steps.last else { return .none }
        if isWet(first) {
            return isWet(last) ? .continuing : .stopping
        }
        return .starting
    }

    /// Step interval, for drawing: up to 15 minutes with Open-Meteo.
    public var stepInterval: TimeInterval {
        guard steps.count >= 2 else { return 15 * 60 }
        return steps[1].date.timeIntervalSince(steps[0].date)
    }

    /// The steps to draw: `maxSteps` from the start of the series, or — when that
    /// window is dry but rain arrives later — a window beginning one step before the
    /// first wet one. Without that second case the card reads "rain starting" over an
    /// empty strip, which is what this port did before.
    ///
    /// DEVIATION: upstream charts the *whole* minutely series (for Open-Meteo that
    /// is 17 days compressed into one narrow card). This charts three hours, so the
    /// bars are readable and the card answers "is it about to rain".
    public func window(maxSteps: Int = 12) -> [MinutelyForecast] {
        guard !steps.isEmpty else { return [] }
        let head = Array(steps.prefix(maxSteps))
        if head.contains(where: isWet) { return head }
        guard let firstWetIndex = steps.firstIndex(where: isWet) else { return head }
        let start = max(firstWetIndex - 1, 0)
        return Array(steps[start..<min(start + maxSteps, steps.count)])
    }

    /// mm per hour, which is the unit upstream's intensity thresholds are written in
    /// (light 5, medium 10, heavy 15). Our steps are 15 minutes of accumulation, so
    /// comparing raw millimetres with those constants would be a factor-of-four lie.
    public static func millimetersPerHour(of step: MinutelyForecast, suggesting stepInterval: TimeInterval) -> Double {
        let seconds = stepInterval > 0 ? stepInterval : 900
        return (step.precipitation?.inMillimeters ?? 0) * 3600 / seconds
    }
}
