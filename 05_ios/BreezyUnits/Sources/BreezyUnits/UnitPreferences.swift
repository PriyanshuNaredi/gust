//
//  UnitPreferences.swift
//  BreezyUnits
//
//  User-selectable *display* units, following upstream's settings. The units
//  package already owns the conversion tables (`TemperatureUnit`, `SpeedUnit`, …);
//  this file only picks one per dimension, remembers the choice, and formats.
//
//  Kept in the package rather than the app because every factor here is testable
//  arithmetic, and a wrong one is invisible until someone compares with Android.
//

import Foundation

public enum DisplayUnit: String, CaseIterable, Codable, Sendable {
    // Temperature
    case celsius, fahrenheit
    // Speed
    case kilometersPerHour, metersPerSecond, milesPerHour, knots, beaufort
    // Pressure
    case hectopascals, millimetersOfMercury, inchesOfMercury
    // Precipitation
    case millimeters, inches
    // Distance
    case kilometers, miles, meters
}

public struct UnitPreferences: Codable, Hashable, Sendable {
    // Stored as identifiers rather than enum types so an old saved value cannot
    // make the whole preferences record fail to decode.
    public var temperature: DisplayUnit = .celsius
    public var speed: DisplayUnit = .kilometersPerHour
    public var pressure: DisplayUnit = .hectopascals
    public var precipitation: DisplayUnit = .millimeters
    public var distance: DisplayUnit = .kilometers
    public var twelveHourClock: Bool = false

    public init() {}

    public init(
        temperature: DisplayUnit,
        speed: DisplayUnit,
        pressure: DisplayUnit,
        precipitation: DisplayUnit,
        distance: DisplayUnit,
        twelveHourClock: Bool = false
    ) {
        self.temperature = temperature
        self.speed = speed
        self.pressure = pressure
        self.precipitation = precipitation
        self.distance = distance
        self.twelveHourClock = twelveHourClock
    }

    // MARK: - Labels

    public var temperatureLabel: String {
        switch temperature {
        case .fahrenheit: return "°F"
        default: return "°C"
        }
    }

    public var speedLabel: String {
        switch speed {
        case .metersPerSecond: return "m/s"
        case .milesPerHour: return "mph"
        case .knots: return "kn"
        case .beaufort: return "Bft"
        default: return "km/h"
        }
    }

    public var pressureLabel: String {
        switch pressure {
        case .millimetersOfMercury: return "mmHg"
        case .inchesOfMercury: return "inHg"
        default: return "hPa"
        }
    }

    public var precipitationLabel: String {
        precipitation == .inches ? "in" : "mm"
    }

    public var distanceLabel: String {
        switch distance {
        case .miles: return "mi"
        case .meters: return "m"
        default: return "km"
        }
    }

    // MARK: - Formatting

    public func value(_ temperature: Temperature) -> Double {
        temperature == temperature ? (self.temperature == .fahrenheit ? temperature.inFahrenheit : temperature.inCelsius) : .nan
    }

    public func string(_ temperature: Temperature?, decimals: Int = 1) -> String {
        guard let temperature else { return "—" }
        let value = self.temperature == .fahrenheit ? temperature.inFahrenheit : temperature.inCelsius
        return String(format: "%.\(decimals)f %@", value, temperatureLabel)
    }

    /// Degrees only, for dense rows where the unit is implied by the header.
    public func degrees(_ temperature: Temperature?) -> String {
        guard let temperature else { return "—" }
        let value = self.temperature == .fahrenheit ? temperature.inFahrenheit : temperature.inCelsius
        return String(format: "%.0f°", value)
    }

    public func string(_ speed: Speed?) -> String {
        guard let speed else { return "—" }
        switch self.speed {
        case .metersPerSecond: return String(format: "%.1f m/s", speed.inMetersPerSecond)
        case .milesPerHour: return String(format: "%.1f mph", speed.inMilesPerHour)
        case .knots: return String(format: "%.1f kn", speed.inKnots)
        case .beaufort: return "\(speed.inBeaufort) Bft"   // bands, not decimals
        default: return String(format: "%.1f km/h", speed.inKilometersPerHour)
        }
    }

    public func string(_ pressure: Pressure?) -> String {
        guard let pressure else { return "—" }
        switch self.pressure {
        case .millimetersOfMercury:
            return String(format: "%.1f mmHg", pressure.inMillimetersOfMercury)
        case .inchesOfMercury:
            return String(format: "%.2f inHg", pressure.inInchesOfMercury)
        default:
            return String(format: "%.1f hPa", pressure.inHectopascals)
        }
    }

    public func string(_ precipitation: Precipitation?) -> String {
        guard let precipitation else { return "—" }
        if self.precipitation == .inches {
            return String(format: "%.2f in", precipitation.inInches)
        }
        return String(format: "%.1f mm", precipitation.inMillimeters)
    }

    public func string(_ distance: Distance?) -> String {
        guard let distance else { return "—" }
        switch self.distance {
        case .miles: return String(format: "%.1f mi", distance.inMiles)
        case .meters: return String(format: "%.0f m", distance.inMeters)
        default: return String(format: "%.1f km", distance.inKilometers)
        }
    }
}