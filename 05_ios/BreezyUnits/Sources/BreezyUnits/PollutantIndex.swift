//
//  PollutantIndex.swift
//  BreezyUnits
//
//  Upstream's air-quality index (`domain/weather/index/PollutantIndex.kt`,
//  LGPL-3.0). The breakpoints are Plume 2023 for particulates and WHO 2021 for the
//  rest, and the index is a piecewise-linear map from concentration to a 0–250+
//  scale. Ported exactly, because an "approximately right" AQI is just a different
//  index and cannot be compared with the Android app's number.
//

import Foundation

public struct PollutantConcentration: Hashable, Sendable, Comparable {
    /// Micrograms per cubic metre — Open-Meteo's unit, and upstream's reference.
    public let microgramsPerCubicMeter: Double

    public init(microgramsPerCubicMeter: Double) {
        self.microgramsPerCubicMeter = microgramsPerCubicMeter
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.microgramsPerCubicMeter < rhs.microgramsPerCubicMeter
    }
}

public extension Double {
    var microgramsPerCubicMeter: PollutantConcentration {
        PollutantConcentration(microgramsPerCubicMeter: self)
    }
}

public enum Pollutant: String, CaseIterable, Sendable {
    case pm25, pm10, o3, no2, so2, co

    /// Concentration breakpoints. Uneven on purpose: they come from different
    /// health-based guidelines per pollutant.
    public var thresholds: [Int] {
        switch self {
        case .pm25: return [0, 5, 15, 30, 60, 150]      // Plume 2023
        case .pm10: return [0, 15, 45, 80, 160, 400]    // Plume 2023
        case .o3: return [0, 50, 100, 160, 240, 480]    // Plume 2023
        case .no2: return [0, 10, 25, 200, 400, 1000]   // Plume 2023
        case .so2: return [0, 20, 40, 270, 500, 960]    // WHO 2021
        case .co: return [0, 2, 4, 35, 100, 230]        // WHO 2021
        }
    }

    /// Molar mass, used upstream for ppb ↔ µg/m³ conversions. Carried for the
    /// detail page; nil where upstream has none.
    public var molarMass: Double? {
        switch self {
        case .pm25, .pm10: return nil
        case .o3: return 48.0
        case .no2: return 46.0055
        case .so2: return 64.066
        case .co: return 28.01
        }
    }
}

public enum PollutantIndex {
    /// The AQI scale itself: 0–20 good, 20–50 fair, 50–100 poor, 100–150 very poor,
    /// 150–250 excessive, and open-ended above.
    public static let aqiThresholds = [0, 20, 50, 100, 150, 250]

    public static let indexFreshAir = aqiThresholds[1]
    public static let indexHighPollution = aqiThresholds[3]
    public static let indexExcessivePollution = aqiThresholds[5]

    /// Piecewise-linear interpolation inside a band; above the last breakpoint the
    /// scale keeps going linearly rather than saturating.
    private static func interpolate(_ cp: Double, _ bpLo: Int, _ bpHi: Int, _ inLo: Int, _ inHi: Int) -> Int {
        let value = (Double(inHi) - Double(inLo)) / (Double(bpHi) - Double(bpLo)) * (cp - Double(bpLo)) + Double(inLo)
        return Int(value.rounded())
    }

    private static func interpolate(_ cp: Double, level: Int, thresholds: [Int]) -> Int {
        if level < thresholds.count - 1 {
            return interpolate(
                cp,
                thresholds[level], thresholds[level + 1],
                aqiThresholds[level], aqiThresholds[level + 1]
            )
        }
        // Linear continuation above the last threshold.
        return Int((cp * Double(aqiThresholds.last!) / Double(thresholds.last!)).rounded())
    }

    /// Index for one pollutant. nil below zero, which is the only value upstream
    /// refuses to map.
    public static func index(of pollutant: Pollutant, concentration: Double?) -> Int? {
        guard let concentration else { return nil }
        let thresholds = pollutant.thresholds
        let level = thresholds.lastIndex { concentration >= Double($0) }
        guard let level else { return nil }
        return interpolate(concentration, level: level, thresholds: thresholds)
    }

    /// Coarse level 0–5 for colouring. nil stays nil.
    public static func level(forIndex aqi: Int?) -> Int? {
        guard let aqi else { return nil }
        let level = aqiThresholds.lastIndex { aqi >= $0 }
        return level
    }
}
