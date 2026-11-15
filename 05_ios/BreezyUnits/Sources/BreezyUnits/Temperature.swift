//
//  Temperature.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../temperature/Temperature.kt` and
//  `TemperatureUnit.kt` (LGPL-3.0). Reference unit: deci-Celsius (Int64).
//

import Foundation

public enum TemperatureUnit: WeatherUnit {
    case deciCelsius
    case celsius
    case fahrenheit
    case kelvin

    public var symbol: String {
        switch self {
        case .deciCelsius, .celsius: return "°C"
        case .fahrenheit: return "°F"
        case .kelvin: return "K"
        }
    }

    // Upstream: convertFromReference / convertToReference closures, verbatim.
    public func fromReference(_ value: Double) -> Double {
        switch self {
        case .deciCelsius: return value
        case .celsius: return value / 10.0
        case .fahrenheit: return 9.0 / 5.0 * (value / 10.0) + 32
        case .kelvin: return 273.15 + value / 10.0
        }
    }

    public func toReference(_ value: Double) -> Double {
        switch self {
        case .deciCelsius: return value
        case .celsius: return value * 10.0
        case .fahrenheit: return 5.0 / 9.0 * (value - 32.0) * 10.0
        case .kelvin: return (value - 273.15) * 10.0
        }
    }
}

public struct Temperature: WeatherValue {
    public static let referenceUnit = TemperatureUnit.deciCelsius
    public let referenceValue: Int64

    public init(referenceValue: Int64) {
        self.referenceValue = referenceValue
    }

    /// Throws on NaN, as upstream does.
    public init(_ value: Double, unit: TemperatureUnit = .celsius) throws {
        let reference = unit.toReference(value)
        guard !reference.isNaN else { throw UnitError.notANumber }
        self.init(referenceValue: Int64(reference.rounded()))
    }

    // Display accessors, mirroring upstream's `inFahrenheit`, `inKelvins`, ...

    /// This temperature in decidegrees Celsius (the storage unit).
    public var inDeciCelsius: Double { converted(to: .deciCelsius) }
    /// Degrees Celsius. Note upstream rounds to deci-Celsius *first*, so this is
    /// not a lossless read of the original input.
    public var inCelsius: Double { converted(to: .celsius) }
    public var inFahrenheit: Double { converted(to: .fahrenheit) }
    public var inKelvins: Double { converted(to: .kelvin) }
}

public enum UnitError: Error, Equatable {
    case notANumber
}

// Convenience constructors, mirroring the Kotlin extension properties
// (`0.celsius`, `32.0.fahrenheit`).
public extension Int {
    var celsius: Temperature { Temperature(referenceValue: Int64((Double(self) * 10.0).rounded())) }
    var deciCelsius: Temperature { Temperature(referenceValue: Int64(self)) }
    var fahrenheit: Temperature { Temperature(referenceValue: Int64(TemperatureUnit.fahrenheit.toReference(Double(self)).rounded())) }
    var kelvin: Temperature { Temperature(referenceValue: Int64(TemperatureUnit.kelvin.toReference(Double(self)).rounded())) }
}

public extension Double {
    var celsius: Temperature { Temperature(referenceValue: Int64((self * 10.0).rounded())) }
    var deciCelsius: Temperature { Temperature(referenceValue: Int64(self.rounded())) }
    var fahrenheit: Temperature { Temperature(referenceValue: Int64(TemperatureUnit.fahrenheit.toReference(self).rounded())) }
    var kelvin: Temperature { Temperature(referenceValue: Int64(TemperatureUnit.kelvin.toReference(self).rounded())) }
}
