//
//  PollenIndex.swift
//  BreezyUnits
//
//  Ported from `domain/weather/index/PollenIndex.kt`.
//
//  Each pollen type has its own concentration breakpoints — grass becomes "high" at a
//  concentration that would still be "low" for birch — and the shared 0..100 index is a
//  piecewise-linear rescale, not a percentage. Both facts are in this file and in its
//  tests, because getting either wrong makes every label plausible and wrong.
//

import Foundation

public struct RGBColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(hex: UInt32) {
        self.red = Double((hex >> 16) & 0xFF)
        self.green = Double((hex >> 8) & 0xFF)
        self.blue = Double(hex & 0xFF)
    }
}

public enum PollenLevel: Int, CaseIterable, Sendable {
    case veryLow, low, moderate, high, veryHigh

    /// `pollen_level_1..5`; level 0 is the separate "None" string.
    public var name: String {
        switch self {
        case .veryLow: return "Very low"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very high"
        }
    }

    /// `pollen_level_colors`.
    public var color: RGBColor {
        switch self {
        case .veryLow: return RGBColor(hex: 0x08C286)
        case .low: return RGBColor(hex: 0x6AD555)
        case .moderate: return RGBColor(hex: 0xFFD741)
        case .high: return RGBColor(hex: 0xFFAB40)
        case .veryHigh: return RGBColor(hex: 0xFF6B40)
        }
    }
}

public extension PollenType {
    /// Upstream's `thresholds`, per type. Values are grains/m³, except the placeholder
    /// `0,1,2,3,4` sets which upstream marks TODO.
    var thresholds: [Int] {
        switch self {
        case .alder: return [0, 10, 60, 100, 500]      // Atmo France
        case .birch: return [0, 10, 60, 100, 500]      // Atmo France
        case .grass: return [0, 3, 30, 50, 250]        // Atmo France
        case .mugwort: return [0, 3, 30, 50, 250]      // Atmo France
        case .olive: return [0, 20, 100, 200, 500]     // Atmo France
        case .ragweed: return [0, 3, 30, 50, 250]      // Atmo France
        }
    }

    /// The shared 0..100 scale every type is rescaled onto.
    static let indexThresholds = [0, 25, 50, 75, 100]
}

public enum PollenIndexCalculator {
    /// `PollenIndex.getIndex(cp)`: find the band, interpolate inside it, and continue
    /// linearly above the last breakpoint rather than clamping — a concentration of
    /// 1000 for grass is genuinely worse than 250, and a clamp would say they are equal.
    public static func index(for type: PollenType, concentration: Double?) -> Int? {
        guard let concentration else { return nil }
        let thresholds = type.thresholds
        guard let level = thresholds.lastIndex(where: { concentration >= Double($0) }) else { return 0 }
        if level < thresholds.count - 1 {
            let low = Double(thresholds[level])
            let high = Double(thresholds[level + 1])
            let indexLow = Double(PollenType.indexThresholds[level])
            let indexHigh = Double(PollenType.indexThresholds[level + 1])
            return Int(((indexHigh - indexLow) / (high - low) * (concentration - low) + indexLow).rounded())
        }
        let lastThreshold = Double(thresholds[thresholds.count - 1])
        let lastIndex = Double(PollenType.indexThresholds.last ?? 100)
        return Int((concentration * lastIndex / lastThreshold).rounded())
    }

    public static func level(for index: Int?) -> PollenLevel? {
        guard let index else { return nil }
        let thresholds = PollenType.indexThresholds
        guard let level = thresholds.lastIndex(where: { index >= $0 }) else { return nil }
        return PollenLevel(rawValue: min(level, PollenLevel.allCases.count - 1))
    }

    /// "None" at zero, otherwise the level's name; nil only when there is no index.
    public static func name(for index: Int?) -> String? {
        guard let index else { return nil }
        if index == 0 { return "None" }
        return level(for: index)?.name
    }

    public static func color(for index: Int?) -> RGBColor? {
        guard let index else { return nil }
        if index == 0 { return RGBColor(hex: 0xBFBFBF) }
        return level(for: index)?.color
    }
}

public extension Pollen {
    func index(of type: PollenType) -> Int? {
        PollenIndexCalculator.index(for: type, concentration: value(of: type))
    }

    /// The type with the highest index, which is what the card shows first.
    var worstType: (type: PollenType, index: Int)? {
        PollenType.allCases
            .compactMap { type in index(of: type).map { (type, $0) } }
            .max { $0.1 < $1.1 }
    }
}
