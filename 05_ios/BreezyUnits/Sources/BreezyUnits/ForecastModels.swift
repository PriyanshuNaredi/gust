//
//  ForecastModels.swift
//  BreezyUnits
//
//  Hourly and daily forecast types, following upstream's `Hourly.kt` / `Daily.kt`
//  naming (LGPL-3.0). Only the fields this port actually renders are carried so
//  far; upstream has more (normals, air quality, pollen, moon phases).
//

import Foundation

public struct HourlyForecast: Hashable, Sendable {
    public let date: Date
    public let weatherCode: WeatherCode?
    public let temperature: Temperature?
    public let apparentTemperature: Temperature?
    public let precipitationProbability: Ratio?
    public let precipitation: Precipitation?
    public let rain: Precipitation?
    public let showers: Precipitation?
    /// Centimetres on the wire, millimetres in every other precipitation field.
    public let snow: Precipitation?
    public let wind: Wind?
    public let uvIndex: Double?
    public let isDay: Bool?
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
        precipitationProbability: Ratio? = nil,
        precipitation: Precipitation? = nil,
        rain: Precipitation? = nil,
        showers: Precipitation? = nil,
        snow: Precipitation? = nil,
        wind: Wind? = nil,
        uvIndex: Double? = nil,
        isDay: Bool? = nil,
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
        self.precipitationProbability = precipitationProbability
        self.precipitation = precipitation
        self.rain = rain
        self.showers = showers
        self.snow = snow
        self.wind = wind
        self.uvIndex = uvIndex
        self.isDay = isDay
        self.relativeHumidity = relativeHumidity
        self.dewPoint = dewPoint
        self.pressure = pressure
        self.cloudCover = cloudCover
        self.visibility = visibility
    }
}

public struct DailyForecast: Hashable, Sendable {
    public let date: Date
    public let temperatureMax: Temperature?
    public let temperatureMin: Temperature?
    public let apparentTemperatureMax: Temperature?
    public let apparentTemperatureMin: Temperature?
    public let sunshineDuration: TimeInterval?
    public let uvIndexMax: Double?
    public let relativeHumidityMean: Ratio?
    public let relativeHumidityMax: Ratio?
    public let relativeHumidityMin: Ratio?
    public let dewPointMean: Temperature?
    public let dewPointMax: Temperature?
    public let dewPointMin: Temperature?
    public let pressureMean: Pressure?
    public let pressureMax: Pressure?
    public let pressureMin: Pressure?
    public let cloudCoverMean: Ratio?
    public let cloudCoverMax: Ratio?
    public let cloudCoverMin: Ratio?
    public let visibilityMean: Distance?
    public let visibilityMax: Distance?
    public let visibilityMin: Distance?

    public init(
        date: Date,
        temperatureMax: Temperature? = nil,
        temperatureMin: Temperature? = nil,
        apparentTemperatureMax: Temperature? = nil,
        apparentTemperatureMin: Temperature? = nil,
        sunshineDuration: TimeInterval? = nil,
        uvIndexMax: Double? = nil,
        relativeHumidityMean: Ratio? = nil,
        relativeHumidityMax: Ratio? = nil,
        relativeHumidityMin: Ratio? = nil,
        dewPointMean: Temperature? = nil,
        dewPointMax: Temperature? = nil,
        dewPointMin: Temperature? = nil,
        pressureMean: Pressure? = nil,
        pressureMax: Pressure? = nil,
        pressureMin: Pressure? = nil,
        cloudCoverMean: Ratio? = nil,
        cloudCoverMax: Ratio? = nil,
        cloudCoverMin: Ratio? = nil,
        visibilityMean: Distance? = nil,
        visibilityMax: Distance? = nil,
        visibilityMin: Distance? = nil
    ) {
        self.date = date
        self.temperatureMax = temperatureMax
        self.temperatureMin = temperatureMin
        self.apparentTemperatureMax = apparentTemperatureMax
        self.apparentTemperatureMin = apparentTemperatureMin
        self.sunshineDuration = sunshineDuration
        self.uvIndexMax = uvIndexMax
        self.relativeHumidityMean = relativeHumidityMean
        self.relativeHumidityMax = relativeHumidityMax
        self.relativeHumidityMin = relativeHumidityMin
        self.dewPointMean = dewPointMean
        self.dewPointMax = dewPointMax
        self.dewPointMin = dewPointMin
        self.pressureMean = pressureMean
        self.pressureMax = pressureMax
        self.pressureMin = pressureMin
        self.cloudCoverMean = cloudCoverMean
        self.cloudCoverMax = cloudCoverMax
        self.cloudCoverMin = cloudCoverMin
        self.visibilityMean = visibilityMean
        self.visibilityMax = visibilityMax
        self.visibilityMin = visibilityMin
    }
}

/// One step of the 15-minute nowcast. Upstream keeps **one entry per time step**
/// with a nullable intensity (`Minutely.precipitationIntensity`), so gaps stay
/// gaps; dropping nulls would slide the whole nowcast earlier in time.
public struct MinutelyForecast: Hashable, Sendable {
    public let date: Date
    public let precipitation: Precipitation?

    public init(date: Date, precipitation: Precipitation? = nil) {
        self.date = date
        self.precipitation = precipitation
    }
}

/// What a main screen shows for one location: upstream's `Weather`, reduced.
public struct Weather: Hashable, Sendable {
    public let current: CurrentObservation?
    public let hourlyForecast: [HourlyForecast]
    public let dailyForecast: [DailyForecast]
    public let minutelyForecast: [MinutelyForecast]
    /// When the source produced this data (upstream keeps it on `base`).
    public let refreshTime: Date

    public init(
        current: CurrentObservation?,
        hourlyForecast: [HourlyForecast],
        dailyForecast: [DailyForecast],
        minutelyForecast: [MinutelyForecast],
        refreshTime: Date
    ) {
        self.current = current
        self.hourlyForecast = hourlyForecast
        self.dailyForecast = dailyForecast
        self.minutelyForecast = minutelyForecast
        self.refreshTime = refreshTime
    }

    /// Upstream's `isMinutelyForecastPrecipitationPossible`: any step with an
    /// intensity above zero. `nil` counts as no precipitation, as it does there.
    public var hasMinutelyPrecipitation: Bool {
        minutelyForecast.contains { ($0.precipitation?.inMillimeters ?? 0) > 0 }
    }

    /// Only the hours at or after `date`. Upstream calls this `nextHourlyForecast`.
    public func hourlyForecast(from date: Date) -> [HourlyForecast] {
        hourlyForecast.filter { $0.date >= date }
    }
}
