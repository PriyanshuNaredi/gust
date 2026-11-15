//
//  OpenMeteoRequest.swift
//  BreezyUnits
//
//  Ported from `sources/openmeteo/OpenMeteoForecastApi.kt` + `OpenMeteoService.kt`
//  (LGPL-3.0). The variable lists are copied verbatim, including their order: the
//  response arrays are positional, so a reordered list is a silent mis-mapping.
//
//  NOT ported here: the Air Quality endpoint (`air-quality-api.open-meteo.com`)
//  and the Copernicus pollen variables; they belong to a later slice.
//

import Foundation

public enum OpenMeteoRequest {
    public static let baseURL = "https://api.open-meteo.com/v1/forecast"

    /// Upstream asks for the model list, not a single model, and joins with ",".
    public static let defaultModel = "best_match"

    /// `daily=` variables, in upstream's order.
    public static let dailyVariables: [String] = [
        "temperature_2m_max", "temperature_2m_min",
        "apparent_temperature_max", "apparent_temperature_min",
        "sunshine_duration", "uv_index_max",
        "relative_humidity_2m_mean", "relative_humidity_2m_max", "relative_humidity_2m_min",
        "dew_point_2m_mean", "dew_point_2m_max", "dew_point_2m_min",
        "pressure_msl_mean", "pressure_msl_max", "pressure_msl_min",
        "cloud_cover_mean", "cloud_cover_max", "cloud_cover_min",
        "visibility_mean", "visibility_max", "visibility_min"
    ]

    /// `hourly=` variables, in upstream's order.
    public static let hourlyVariables: [String] = [
        "temperature_2m", "apparent_temperature",
        "precipitation_probability", "precipitation", "rain", "showers", "snowfall",
        "weather_code",
        "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
        "uv_index", "is_day",
        "relative_humidity_2m", "dew_point_2m",
        "pressure_msl", "cloud_cover", "visibility"
    ]

    /// `current=` variables, in upstream's order.
    public static let currentVariables: [String] = [
        "temperature_2m", "apparent_temperature", "weather_code",
        "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
        "uv_index", "relative_humidity_2m", "dew_point_2m",
        "pressure_msl", "cloud_cover", "visibility"
    ]

    /// Upstream requests `minutely_15=precipitation` only.
    public static let minutelyVariables: [String] = ["precipitation"]

    /// Builds the request URL exactly as upstream does:
    /// `timezone=auto`, `timeformat=unixtime`, `forecast_days=16`, `past_days=1`
    /// and `windspeed_unit=ms` (so every speed arrives in m/s and is converted
    /// once, here, into the reference unit).
    public static func url(
        latitude: Double,
        longitude: Double,
        model: String = defaultModel,
        forecastDays: Int = 16,
        pastDays: Int = 1,
        includeForecast: Bool = true,
        includeCurrent: Bool = true,
        includeMinutely: Bool = true
    ) -> URL {
        var components = URLComponents(string: baseURL)!
        var items: [URLQueryItem] = [
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "models", value: model),
            // Empty strings, not absent keys: upstream sends "" when a feature is
            // not requested, and Open-Meteo treats "" as "no variables".
            .init(name: "daily", value: includeForecast ? dailyVariables.joined(separator: ",") : ""),
            .init(name: "hourly", value: includeForecast ? hourlyVariables.joined(separator: ",") : ""),
            .init(name: "minutely_15", value: includeMinutely ? minutelyVariables.joined(separator: ",") : ""),
            .init(name: "current", value: includeCurrent ? currentVariables.joined(separator: ",") : ""),
            .init(name: "forecast_days", value: String(forecastDays)),
            .init(name: "past_days", value: String(pastDays)),
            .init(name: "windspeed_unit", value: "ms")
        ]
        // Stable order keeps recorded URLs diffable in tests.
        items.sort { $0.name < $1.name }
        components.queryItems = items
        return components.url!
    }
}
