//
//  OpenMeteoResponse.swift
//  BreezyUnits
//
//  Ported from `sources/openmeteo/json/*.kt` (LGPL-3.0). Coding keys are the
//  upstream `@SerialName` values verbatim.
//
//  Two things worth knowing before editing:
//  - Arrays are positional and may legitimately contain nulls (Open-Meteo emits
//    null for a variable it could not compute), so every element is Optional.
//  - The payload has an `error`/`reason` pair, but errors arrive with HTTP 200
//    in some cases, so decoding alone is not a success check.
//

import Foundation

public struct OpenMeteoWeatherResult: Decodable {
    public let latitude: Double?
    public let longitude: Double?
    public let timezone: String?
    public let utcOffsetSeconds: Int?
    public let current: OpenMeteoCurrent?
    public let daily: OpenMeteoDaily?
    public let hourly: OpenMeteoHourly?
    public let minutelyFifteen: OpenMeteoMinutely?
    public let error: Bool?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone, error, reason
        case utcOffsetSeconds = "utc_offset_seconds"
        case current, daily, hourly
        case minutelyFifteen = "minutely_15"
    }
}

public struct OpenMeteoCurrent: Decodable {
    public let time: Int64
    public let interval: Int?
    public let temperature: Double?
    public let apparentTemperature: Double?
    public let weatherCode: Int?
    public let windSpeed: Double?
    public let windDirection: Double?
    public let windGusts: Double?
    public let uvIndex: Double?
    public let relativeHumidity: Int?
    public let dewPoint: Double?
    public let pressureMsl: Double?
    public let cloudCover: Int?
    public let visibility: Double?

    enum CodingKeys: String, CodingKey {
        case time, interval, visibility
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case weatherCode = "weather_code"
        case windSpeed = "wind_speed_10m"
        case windDirection = "wind_direction_10m"
        case windGusts = "wind_gusts_10m"
        case uvIndex = "uv_index"
        case relativeHumidity = "relative_humidity_2m"
        case dewPoint = "dew_point_2m"
        case pressureMsl = "pressure_msl"
        case cloudCover = "cloud_cover"
    }
}

public struct OpenMeteoMinutely: Decodable {
    public let time: [Int64]
    public let precipitation: [Double?]?
}

public struct OpenMeteoHourly: Decodable {
    public let time: [Int64]
    public let temperature: [Double?]?
    public let apparentTemperature: [Double?]?
    public let precipitationProbability: [Int?]?
    public let precipitation: [Double?]?
    public let rain: [Double?]?
    public let showers: [Double?]?
    /// Centimetres, unlike every other precipitation field (which is millimetres).
    public let snowfall: [Double?]?
    public let weatherCode: [Int?]?
    public let windSpeed: [Double?]?
    public let windDirection: [Int?]?
    public let windGusts: [Double?]?
    public let uvIndex: [Double?]?
    public let isDay: [Int?]?
    public let relativeHumidity: [Int?]?
    public let dewPoint: [Double?]?
    public let pressureMsl: [Double?]?
    public let cloudCover: [Int?]?
    public let visibility: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time, precipitation, rain, showers, snowfall, visibility
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case weatherCode = "weather_code"
        case windSpeed = "wind_speed_10m"
        case windDirection = "wind_direction_10m"
        case windGusts = "wind_gusts_10m"
        case uvIndex = "uv_index"
        case isDay = "is_day"
        case relativeHumidity = "relative_humidity_2m"
        case dewPoint = "dew_point_2m"
        case pressureMsl = "pressure_msl"
        case cloudCover = "cloud_cover"
    }
}

public struct OpenMeteoDaily: Decodable {
    public let time: [Int64]
    public let temperatureMax: [Double?]?
    public let temperatureMin: [Double?]?
    public let apparentTemperatureMax: [Double?]?
    public let apparentTemperatureMin: [Double?]?
    /// Seconds.
    public let sunshineDuration: [Double?]?
    public let uvIndexMax: [Double?]?
    public let relativeHumidityMean: [Int?]?
    public let relativeHumidityMax: [Int?]?
    public let relativeHumidityMin: [Int?]?
    public let dewPointMean: [Double?]?
    public let dewPointMax: [Double?]?
    public let dewPointMin: [Double?]?
    public let pressureMslMean: [Double?]?
    public let pressureMslMax: [Double?]?
    public let pressureMslMin: [Double?]?
    public let cloudCoverMean: [Int?]?
    public let cloudCoverMax: [Int?]?
    public let cloudCoverMin: [Int?]?
    /// Metres.
    public let visibilityMean: [Double?]?
    public let visibilityMax: [Double?]?
    public let visibilityMin: [Double?]?
    /// Unix seconds, like every other timestamp in the payload.
    public let sunrise: [Int64?]?
    public let sunset: [Int64?]?

    enum CodingKeys: String, CodingKey {
        case time, sunrise, sunset
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
        case apparentTemperatureMax = "apparent_temperature_max"
        case apparentTemperatureMin = "apparent_temperature_min"
        case sunshineDuration = "sunshine_duration"
        case uvIndexMax = "uv_index_max"
        case relativeHumidityMean = "relative_humidity_2m_mean"
        case relativeHumidityMax = "relative_humidity_2m_max"
        case relativeHumidityMin = "relative_humidity_2m_min"
        case dewPointMean = "dew_point_2m_mean"
        case dewPointMax = "dew_point_2m_max"
        case dewPointMin = "dew_point_2m_min"
        case pressureMslMean = "pressure_msl_mean"
        case pressureMslMax = "pressure_msl_max"
        case pressureMslMin = "pressure_msl_min"
        case cloudCoverMean = "cloud_cover_mean"
        case cloudCoverMax = "cloud_cover_max"
        case cloudCoverMin = "cloud_cover_min"
        case visibilityMean = "visibility_mean"
        case visibilityMax = "visibility_max"
        case visibilityMin = "visibility_min"
    }
}
