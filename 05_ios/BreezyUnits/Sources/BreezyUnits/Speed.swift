//
//  Speed.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../speed/SpeedUnit.kt` and `Speed.kt` (LGPL-3.0).
//  Reference unit: centimetres per second.
//

import Foundation

public enum SpeedUnit: WeatherUnit {
    case centimeterPerSecond
    case meterPerSecond
    case kilometerPerHour
    case milePerHour
    case knot
    case footPerSecond
    case beaufortScale

    /// Beaufort boundaries in cm/s, verbatim from the upstream companion object.
    static let windSpeed1: Int64 = 30
    static let windSpeed2: Int64 = 160
    static let windSpeed3: Int64 = 340
    static let windSpeed4: Int64 = 550
    static let windSpeed5: Int64 = 800
    static let windSpeed6: Int64 = 1080
    static let windSpeed7: Int64 = 1390
    static let windSpeed8: Int64 = 1720
    static let windSpeed9: Int64 = 2080
    static let windSpeed10: Int64 = 2450
    static let windSpeed11: Int64 = 2850
    static let windSpeed12: Int64 = 3270

    public var symbol: String {
        switch self {
        case .centimeterPerSecond: return "cm/s"
        case .meterPerSecond: return "m/s"
        case .kilometerPerHour: return "km/h"
        case .milePerHour: return "mph"
        case .knot: return "kn"
        case .footPerSecond: return "ft/s"
        case .beaufortScale: return "Bft"
        }
    }

    public func fromReference(_ value: Double) -> Double {
        switch self {
        case .centimeterPerSecond: return value
        case .meterPerSecond: return value / 100.0
        case .kilometerPerHour: return value * 0.036
        case .milePerHour: return value / 44.704
        case .knot: return value * 0.036 / 1.852
        case .footPerSecond: return value / 30.48
        case .beaufortScale:
            // Upstream switches on the *integer* cm/s value, not a rounded double.
            switch Int64(value) {
            case 0..<Self.windSpeed1: return 0
            case Self.windSpeed1..<Self.windSpeed2: return 1
            case Self.windSpeed2..<Self.windSpeed3: return 2
            case Self.windSpeed3..<Self.windSpeed4: return 3
            case Self.windSpeed4..<Self.windSpeed5: return 4
            case Self.windSpeed5..<Self.windSpeed6: return 5
            case Self.windSpeed6..<Self.windSpeed7: return 6
            case Self.windSpeed7..<Self.windSpeed8: return 7
            case Self.windSpeed8..<Self.windSpeed9: return 8
            case Self.windSpeed9..<Self.windSpeed10: return 9
            case Self.windSpeed10..<Self.windSpeed11: return 10
            case Self.windSpeed11..<Self.windSpeed12: return 11
            case Self.windSpeed12...: return 12
            default: return 0
            }
        }
    }

    public func toReference(_ value: Double) -> Double {
        switch self {
        case .centimeterPerSecond: return value
        case .meterPerSecond: return value * 100.0
        case .kilometerPerHour: return value / 0.036
        case .milePerHour: return value * 44.704
        case .knot: return value * 1.852 / 0.036
        case .footPerSecond: return value * 30.48
        case .beaufortScale:
            switch value {
            case 0..<1: return 0
            case 1..<2: return Double(Self.windSpeed1)
            case 2..<3: return Double(Self.windSpeed2)
            case 3..<4: return Double(Self.windSpeed3)
            case 4..<5: return Double(Self.windSpeed4)
            case 5..<6: return Double(Self.windSpeed5)
            case 6..<7: return Double(Self.windSpeed6)
            case 7..<8: return Double(Self.windSpeed7)
            case 8..<9: return Double(Self.windSpeed8)
            case 9..<10: return Double(Self.windSpeed9)
            case 10..<11: return Double(Self.windSpeed10)
            case 11..<12: return Double(Self.windSpeed11)
            case 12...: return Double(Self.windSpeed12)
            default: return 0
            }
        }
    }
}

public struct Speed: WeatherValue {
    public static let referenceUnit = SpeedUnit.centimeterPerSecond
    public let referenceValue: Int64

    public init(referenceValue: Int64) {
        self.referenceValue = referenceValue
    }

    public var inCentimetersPerSecond: Double { converted(to: .centimeterPerSecond) }
    public var inMetersPerSecond: Double { converted(to: .meterPerSecond) }
    public var inKilometersPerHour: Double { converted(to: .kilometerPerHour) }
    public var inMilesPerHour: Double { converted(to: .milePerHour) }
    public var inKnots: Double { converted(to: .knot) }
    public var inFeetPerSecond: Double { converted(to: .footPerSecond) }
    public var inBeaufort: Int { Int(converted(to: .beaufortScale)) }
}

public extension Double {
    var centimetersPerSecond: Speed { Speed(referenceValue: Int64(rounded())) }
    var metersPerSecond: Speed { Speed(referenceValue: Int64((self * 100.0).rounded())) }
    var kilometersPerHour: Speed { Speed(referenceValue: Int64((self / 0.036).rounded())) }
    var milesPerHour: Speed { Speed(referenceValue: Int64((self * 44.704).rounded())) }
    var knots: Speed { Speed(referenceValue: Int64((self * 1.852 / 0.036).rounded())) }
}

public extension Int {
    var centimetersPerSecond: Speed { Speed(referenceValue: Int64(self)) }
    var metersPerSecond: Speed { Speed(referenceValue: Int64(self * 100)) }
    var kilometersPerHour: Speed { Speed(referenceValue: Int64((Double(self) / 0.036).rounded())) }
    var milesPerHour: Speed { Speed(referenceValue: Int64((Double(self) * 44.704).rounded())) }
    var knots: Speed { Speed(referenceValue: Int64((Double(self) * 1.852 / 0.036).rounded())) }
    var beaufort: Speed { Speed(referenceValue: Int64(SpeedUnit.beaufortScale.toReference(Double(self)).rounded())) }
}
