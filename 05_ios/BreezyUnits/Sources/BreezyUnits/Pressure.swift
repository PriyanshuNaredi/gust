//
//  Pressure.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../pressure/PressureUnit.kt` (LGPL-3.0).
//  Reference unit: pascal.
//

import Foundation

public enum PressureUnit: WeatherUnit {
    case pascal
    case hectopascal
    case kilopascal
    case millibar
    case atmosphere
    case millimeterOfMercury
    case inchOfMercury

    public var symbol: String {
        switch self {
        case .pascal: return "Pa"
        case .hectopascal: return "hPa"
        case .kilopascal: return "kPa"
        case .millibar: return "mbar"
        case .atmosphere: return "atm"
        case .millimeterOfMercury: return "mmHg"
        case .inchOfMercury: return "inHg"
        }
    }

    public func fromReference(_ value: Double) -> Double {
        switch self {
        case .pascal: return value
        case .hectopascal: return value / 100.0
        case .kilopascal: return value / 1000.0
        case .millibar: return value / 100.0
        case .atmosphere: return value / 101_325.0
        case .millimeterOfMercury: return value * 760.0 / 101_325.0
        case .inchOfMercury: return value * 760.0 / 101_325.0 / 25.4
        }
    }

    public func toReference(_ value: Double) -> Double {
        switch self {
        case .pascal: return value
        case .hectopascal: return value * 100.0
        case .kilopascal: return value * 1000.0
        case .millibar: return value * 100.0
        case .atmosphere: return value * 101_325.0
        case .millimeterOfMercury: return value * 101_325.0 / 760.0
        case .inchOfMercury: return value * 25.4 * 101_325.0 / 760.0
        }
    }
}

public struct Pressure: WeatherValue {
    public static let referenceUnit = PressureUnit.pascal
    public let referenceValue: Int64

    public init(referenceValue: Int64) {
        self.referenceValue = referenceValue
    }

    public var inPascals: Double { converted(to: .pascal) }
    public var inHectopascals: Double { converted(to: .hectopascal) }
    public var inKilopascals: Double { converted(to: .kilopascal) }
    public var inMillibars: Double { converted(to: .millibar) }
    public var inAtmospheres: Double { converted(to: .atmosphere) }
    public var inMillimetersOfMercury: Double { converted(to: .millimeterOfMercury) }
    public var inInchesOfMercury: Double { converted(to: .inchOfMercury) }
}

public extension Double {
    var pascals: Pressure { Pressure(referenceValue: Int64(rounded())) }
    var hectopascals: Pressure { Pressure(referenceValue: Int64((self * 100.0).rounded())) }
    var kilopascals: Pressure { Pressure(referenceValue: Int64((self * 1000.0).rounded())) }
    var millibars: Pressure { Pressure(referenceValue: Int64((self * 100.0).rounded())) }
}

public extension Int {
    var pascals: Pressure { Pressure(referenceValue: Int64(self)) }
    var hectopascals: Pressure { Pressure(referenceValue: Int64(self * 100)) }
    var kilopascals: Pressure { Pressure(referenceValue: Int64(self * 1000)) }
    var millibars: Pressure { Pressure(referenceValue: Int64(self * 100)) }
}
