//
//  OpenMeteoAirQuality.swift
//  BreezyUnits
//
//  The second Open-Meteo endpoint, ported from `OpenMeteoAirQualityApi.kt` and the
//  air-quality half of `OpenMeteoService.kt` (LGPL-3.0).
//
//  It is a different host and a different request shape from the forecast call:
//  no `models`, no `windspeed_unit`, seven forecast days instead of sixteen, and
//  hourly variables only — there is no `current` block on this endpoint.
//

import Foundation

public enum OpenMeteoAirQualityRequest {
    public static let baseURL = "https://air-quality-api.open-meteo.com/v1/air-quality"

    /// Upstream's order.
    public static let hourlyVariables: [String] = [
        "pm10", "pm2_5", "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"
    ]

    /// Pollen variables are only requested when the source advertises POLEN support.
    /// This port does not request them yet; listed so the shape is documented.
    public static let pollenVariables: [String] = [
        "alder_pollen", "birch_pollen", "grass_pollen", "mugwort_pollen", "olive_pollen", "ragweed_pollen"
    ]

    public static func url(
        latitude: Double,
        longitude: Double,
        includePollen: Bool = false,
        forecastDays: Int = 7,
        pastDays: Int = 1,
        baseURL: String = OpenMeteoAirQualityRequest.baseURL
    ) -> URL {
        var components = URLComponents(string: baseURL)!
        let variables = includePollen ? hourlyVariables + pollenVariables : hourlyVariables
        var items: [URLQueryItem] = [
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "hourly", value: variables.joined(separator: ",")),
            .init(name: "forecast_days", value: String(forecastDays)),
            .init(name: "past_days", value: String(pastDays))
        ]
        items.sort { $0.name < $1.name }
        components.queryItems = items
        return components.url!
    }
}

public struct OpenMeteoAirQualityResult: Decodable {
    public let latitude: Double?
    public let longitude: Double?
    public let timezone: String?
    public let utcOffsetSeconds: Int?
    public let hourly: OpenMeteoAirQualityHourly?
    public let error: Bool?
    public let reason: String?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude, timezone, hourly, error, reason
        case utcOffsetSeconds = "utc_offset_seconds"
    }
}

public struct OpenMeteoAirQualityHourly: Decodable {
    public let time: [Int64]
    public let pm10: [Double?]?
    public let pm25: [Double?]?
    public let carbonMonoxide: [Double?]?
    public let nitrogenDioxide: [Double?]?
    public let sulphurDioxide: [Double?]?
    public let ozone: [Double?]?
    public let alderPollen: [Double?]?
    public let birchPollen: [Double?]?
    public let grassPollen: [Double?]?
    public let mugwortPollen: [Double?]?
    public let olivePollen: [Double?]?
    public let ragweedPollen: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time, ozone
        case pm10
        case pm25 = "pm2_5"
        case carbonMonoxide = "carbon_monoxide"
        case nitrogenDioxide = "nitrogen_dioxide"
        case sulphurDioxide = "sulphur_dioxide"
        case alderPollen = "alder_pollen"
        case birchPollen = "birch_pollen"
        case grassPollen = "grass_pollen"
        case mugwortPollen = "mugwort_pollen"
        case olivePollen = "olive_pollen"
        case ragweedPollen = "ragweed_pollen"
    }
}

public extension OpenMeteoMapping {
    /// Upstream keys these by timestamp, so hours with no pollutants simply have no
    /// entry rather than an empty one.
    static func airQualityByDate(from raw: OpenMeteoAirQualityHourly?) -> [Date: AirQuality] {
        guard let raw else { return [:] }
        var result: [Date: AirQuality] = [:]
        for index in raw.time.indices {
            func value(_ array: [Double?]?) -> PollutantConcentration? {
                guard let array, index < array.count, let element = array[index] else { return nil }
                return element.microgramsPerCubicMeter
            }
            let quality = AirQuality(
                pm25: value(raw.pm25),
                pm10: value(raw.pm10),
                o3: value(raw.ozone),
                no2: value(raw.nitrogenDioxide),
                so2: value(raw.sulphurDioxide),
                co: value(raw.carbonMonoxide)
            )
            result[date(fromUnixSeconds: raw.time[index])] = quality
        }
        return result
    }
}
