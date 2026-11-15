//
//  Distance.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../distance/DistanceUnit.kt` (LGPL-3.0).
//  Reference unit: metre.
//

import Foundation

public enum DistanceUnit: WeatherUnit {
    case meter
    case kilometer
    case mile
    case nauticalMile
    case foot

    public var symbol: String {
        switch self {
        case .meter: return "m"
        case .kilometer: return "km"
        case .mile: return "mi"
        case .nauticalMile: return "nmi"
        case .foot: return "ft"
        }
    }

    public func fromReference(_ value: Double) -> Double {
        switch self {
        case .meter: return value
        case .kilometer: return value / 1000.0
        case .mile: return value / 1609.344
        case .nauticalMile: return value / 1852.0
        case .foot: return value * 3.28084
        }
    }

    public func toReference(_ value: Double) -> Double {
        switch self {
        case .meter: return value
        case .kilometer: return value * 1000.0
        case .mile: return value * 1609.344
        case .nauticalMile: return value * 1852.0
        case .foot: return value / 3.28084
        }
    }
}

public struct Distance: WeatherValue {
    public static let referenceUnit = DistanceUnit.meter
    public let referenceValue: Int64

    public init(referenceValue: Int64) {
        self.referenceValue = referenceValue
    }

    public var inMeters: Double { converted(to: .meter) }
    public var inKilometers: Double { converted(to: .kilometer) }
    public var inMiles: Double { converted(to: .mile) }
    public var inNauticalMiles: Double { converted(to: .nauticalMile) }
    public var inFeet: Double { converted(to: .foot) }
}

public extension Double {
    var meters: Distance { Distance(referenceValue: Int64(rounded())) }
    var kilometers: Distance { Distance(referenceValue: Int64((self * 1000.0).rounded())) }
    var miles: Distance { Distance(referenceValue: Int64((self * 1609.344).rounded())) }
    var nauticalMiles: Distance { Distance(referenceValue: Int64((self * 1852.0).rounded())) }
    var feet: Distance { Distance(referenceValue: Int64((self / 3.28084).rounded())) }
}

public extension Int {
    var meters: Distance { Distance(referenceValue: Int64(self)) }
    var kilometers: Distance { Distance(referenceValue: Int64(self * 1000)) }
    var miles: Distance { Distance(referenceValue: Int64((Double(self) * 1609.344).rounded())) }
    var feet: Distance { Distance(referenceValue: Int64((Double(self) / 3.28084).rounded())) }
}
