//
//  Ratio.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../ratio/RatioUnit.kt` (LGPL-3.0).
//  Reference unit: permille. Humidity, cloud cover and probabilities all use it.
//

import Foundation

public enum RatioUnit: WeatherUnit {
    case permille
    case percent
    case fraction

    public var symbol: String {
        switch self {
        case .permille: return "‰"
        case .percent: return "%"
        case .fraction: return ""
        }
    }

    public func fromReference(_ value: Double) -> Double {
        switch self {
        case .permille: return value
        case .percent: return value / 10.0
        case .fraction: return value / 1000.0
        }
    }

    public func toReference(_ value: Double) -> Double {
        switch self {
        case .permille: return value
        case .percent: return value * 10.0
        case .fraction: return value * 1000.0
        }
    }
}

public struct Ratio: WeatherValue {
    public static let referenceUnit = RatioUnit.permille
    public let referenceValue: Int64

    public init(referenceValue: Int64) {
        self.referenceValue = referenceValue
    }

    public var inPermille: Double { converted(to: .permille) }
    public var inPercent: Double { converted(to: .percent) }
    public var inFraction: Double { converted(to: .fraction) }

    /// Upstream clamps ratios to 0…100 % before display in several places; this is
    /// the same clamp expressed once.
    public var clamped: Ratio {
        Ratio(referenceValue: min(max(referenceValue, 0), 1000))
    }
}

public extension Double {
    var permille: Ratio { Ratio(referenceValue: Int64(rounded())) }
    var percent: Ratio { Ratio(referenceValue: Int64((self * 10.0).rounded())) }
    var fraction: Ratio { Ratio(referenceValue: Int64((self * 1000.0).rounded())) }
}

public extension Int {
    var permille: Ratio { Ratio(referenceValue: Int64(self)) }
    var percent: Ratio { Ratio(referenceValue: Int64(self * 10)) }
}
