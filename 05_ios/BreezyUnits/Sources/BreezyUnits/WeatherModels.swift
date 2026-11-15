//
//  WeatherModels.swift
//  BreezyUnits
//
//  The first slice of the ported domain model, following
//  `domain/.../weather/model/Current.kt` (LGPL-3.0). Field names and the
//  "everything is optional" style are upstream's: a weather source is allowed to
//  return a partial observation, and the UI decides what to hide.
//

import Foundation

/// Wind, matching upstream's `Wind` (speed, direction in degrees, gusts).
public struct Wind: Hashable, Sendable {
    public let speed: Speed?
    /// Degrees from north, as the source reports it.
    public let direction: Double?
    public let gusts: Speed?

    public init(speed: Speed? = nil, direction: Double? = nil, gusts: Speed? = nil) {
        self.speed = speed
        self.direction = direction
        self.gusts = gusts
    }
}

/// A current observation. Not the full upstream `Current` — this slice carries the
/// fields the header and the first cards need.
public struct CurrentObservation: Hashable, Sendable {
    public let date: Date
    /// Raw WMO code as sent by the source. Mapping to Breezy's `WeatherCode`
    /// families is a separate slice, deliberately not guessed here.
    public let weatherCode: WeatherCode?
    public let temperature: Temperature?
    /// The source's own "feels like", not our computed humidex/wind chill.
    public let apparentTemperature: Temperature?
    public let wind: Wind?
    public let uvIndex: Double?
    public let relativeHumidity: Ratio?
    public let dewPoint: Temperature?
    public let pressure: Pressure?
    public let cloudCover: Ratio?
    public let visibility: Distance?

    public init(
        date: Date,
        weatherCode: WeatherCode? = nil,
        temperature: Temperature? = nil,
        apparentTemperature: Temperature? = nil,
        wind: Wind? = nil,
        uvIndex: Double? = nil,
        relativeHumidity: Ratio? = nil,
        dewPoint: Temperature? = nil,
        pressure: Pressure? = nil,
        cloudCover: Ratio? = nil,
        visibility: Distance? = nil
    ) {
        self.date = date
        self.weatherCode = weatherCode
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.wind = wind
        self.uvIndex = uvIndex
        self.relativeHumidity = relativeHumidity
        self.dewPoint = dewPoint
        self.pressure = pressure
        self.cloudCover = cloudCover
        self.visibility = visibility
    }
}
