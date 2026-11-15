//
//  Precipitation.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../precipitation/PrecipitationUnit.kt` (LGPL-3.0).
//  Reference unit: micrometres.
//

import Foundation

public enum PrecipitationUnit: FactorConvertibleUnit {
    /// The reference unit itself.
    case micrometer
    case millimeter
    case centimeter
    case inch
    /// Same physical quantity as millimetres, expressed per square metre.
    case literPerSquareMeter

    public var symbol: String {
        switch self {
        case .micrometer: return "µm"
        case .millimeter, .literPerSquareMeter: return "mm"
        case .centimeter: return "cm"
        case .inch: return "in"
        }
    }

    public static var factorToReference: Double { 1 }

    public func fromReference(_ value: Double) -> Double {
        switch self {
        case .micrometer: return value
        case .millimeter: return value / 1000.0
        case .centimeter: return value / 10_000.0
        case .inch: return value / 25_400.0
        case .literPerSquareMeter: return value / 1000.0
        }
    }

    public func toReference(_ value: Double) -> Double {
        switch self {
        case .micrometer: return value
        case .millimeter: return value * 1000.0
        case .centimeter: return value * 10_000.0
        case .inch: return value * 25_400.0
        case .literPerSquareMeter: return value * 1000.0
        }
    }
}

public struct Precipitation: WeatherValue {
    public static let referenceUnit = PrecipitationUnit.micrometer
    public let referenceValue: Int64

    public init(referenceValue: Int64) {
        self.referenceValue = referenceValue
    }

    public var inMicrometers: Double { converted(to: .micrometer) }
    public var inMillimeters: Double { converted(to: .millimeter) }
    public var inCentimeters: Double { converted(to: .centimeter) }
    public var inInches: Double { converted(to: .inch) }
}

public extension Double {
    var micrometers: Precipitation { Precipitation(referenceValue: Int64(rounded())) }
    var millimeters: Precipitation { Precipitation(referenceValue: Int64((self * 1000.0).rounded())) }
    var centimeters: Precipitation { Precipitation(referenceValue: Int64((self * 10_000.0).rounded())) }
    var inches: Precipitation { Precipitation(referenceValue: Int64((self * 25_400.0).rounded())) }
}

public extension Int {
    var micrometers: Precipitation { Precipitation(referenceValue: Int64(self)) }
    var millimeters: Precipitation { Precipitation(referenceValue: Int64(self * 1000)) }
    var centimeters: Precipitation { Precipitation(referenceValue: Int64(self * 10_000)) }
    var inches: Precipitation { Precipitation(referenceValue: Int64(self * 25_400)) }
}

// MARK: - Computing

/// Snow-to-liquid ratio table, verbatim from `PrecipitationComputing.kt`.
private let snowToLiquidRatios: [(temperature: Double, ratio: Double)] = [
    (-300.0, 7.2), (-30.0, 7.2), (-28.0, 6.8), (-26.0, 7.0), (-24.0, 8.8),
    (-22.0, 12.0), (-20.0, 18.0), (-18.0, 23.0), (-16.0, 26.0), (-14.0, 22.5),
    (-12.0, 17.5), (-10.0, 12.0), (-8.0, 9.5), (-6.0, 9.0), (-4.0, 8.5),
    (-2.0, 7.0), (0.0, 3.0), (1.0, 1.0), (300.0, 1.0)
]

/// Upstream interpolates linearly between table rows rather than stepping.
public func snowToLiquidRatio(temperature: Temperature?) -> Double {
    guard let temperature else { return 7.2 }
    let celsius = temperature.inCelsius
    for (index, row) in snowToLiquidRatios.enumerated() {
        if index >= snowToLiquidRatios.count - 1 { return row.ratio }
        let next = snowToLiquidRatios[index + 1]
        if celsius >= row.temperature && celsius < next.temperature {
            return row.ratio
                + (next.ratio - row.ratio) / (next.temperature - row.temperature)
                * (celsius - row.temperature)
        }
    }
    return 1.0
}

/// Total precipitation as liquid water: rain + snow/ratio + ice*0.92.
public func computeTotalPrecipitation(
    temperature: Temperature?,
    rain: Precipitation?,
    snow: Precipitation?,
    ice: Precipitation?
) -> Precipitation? {
    if rain == nil && snow == nil && ice == nil { return nil }
    let snowEquivalent = snow.map { Int64(($0.converted(to: .micrometer) / snowToLiquidRatio(temperature: temperature)).rounded()) }
    let iceEquivalent = ice.map { Int64(($0.converted(to: .micrometer) * 0.92).rounded()) }
    let total = (rain?.referenceValue ?? 0) + (snowEquivalent ?? 0) + (iceEquivalent ?? 0)
    return Precipitation(referenceValue: total)
}
