//
//  MoonPhase.swift
//  BreezyUnits
//
//  Open-Meteo serves no moon data, so this port computes the phase instead of
//  leaving the card empty. Upstream gets moon rise/set/phase from sources that
//  provide it; for Open-Meteo it shows nothing at all.
//
//  DEVIATION (recorded in the parity spec): phase only — no moonrise or moonset.
//  A synodic-mean calculation is accurate to a few hours, which is fine for an
//  illumination fraction and not fine for a rise time.
//

import Foundation

public struct MoonPhase: Hashable, Sendable {
    /// 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
    public let age: Double
    /// 0…1, fraction of the disc lit.
    public let illumination: Double

    /// Mean synodic month, in days.
    public static let synodicMonth = 29.530588853
    /// A known new moon: 2000-01-06 18:14 UTC.
    private static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    public init(date: Date) {
        let days = date.timeIntervalSince(Self.referenceNewMoon) / 86_400
        // Positive modulo: dates before the reference must not wrap negative.
        var age = days.truncatingRemainder(dividingBy: Self.synodicMonth)
        if age < 0 { age += Self.synodicMonth }
        self.age = age
        self.illumination = (1 - cos(2 * .pi * age / Self.synodicMonth)) / 2
    }

    /// Which quarter the moon is in, using the conventional eight names upstream
    /// also shows.
    public var name: String {
        let fraction = age / Self.synodicMonth
        switch fraction {
        case ..<0.0625: return "New moon"
        case ..<0.1875: return "Waxing crescent"
        case ..<0.3125: return "First quarter"
        case ..<0.4375: return "Waxing gibbous"
        case ..<0.5625: return "Full moon"
        case ..<0.6875: return "Waning gibbous"
        case ..<0.8125: return "Last quarter"
        case ..<0.9375: return "Waning crescent"
        default: return "New moon"
        }
    }

    /// SF Symbol closest to the phase; the app uses it instead of a drawn moon.
    public var symbolName: String {
        let fraction = age / Self.synodicMonth
        switch fraction {
        case ..<0.0625, 0.9375...: return "moon.fill"
        case ..<0.1875: return "moon.stars.fill"
        case ..<0.3125: return "moon.first.quarter.fill"
        case ..<0.4375: return "moon.first.quarter.fill"
        case ..<0.5625: return "moon.fill"
        case ..<0.6875: return "moon.last.quarter.fill"
        case ..<0.8125: return "moon.last.quarter.fill"
        default: return "moon.stars.fill"
        }
    }
}
