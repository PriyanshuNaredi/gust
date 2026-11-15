//
//  WeatherCode.swift
//  BreezyUnits
//
//  Breezy's own twelve weather families (`domain/.../reference/WeatherCode.kt`,
//  LGPL-3.0), and Open-Meteo's WMO mapping copied from
//  `OpenMeteoService.getWeatherCode` — including which WMO codes it maps to
//  nothing at all.
//

import Foundation

public enum WeatherCode: String, CaseIterable, Sendable {
    case clear, partlyCloudy = "partly_cloudy", cloudy, rain, snow, wind, fog, haze, sleet, hail, thunder, thunderstorm
}

public extension OpenMeteoMapping {
    /// Verbatim from upstream. Unmapped codes return nil rather than a guess, so an
    /// unknown code shows no icon instead of the wrong one.
    static func weatherCode(fromWMO code: Int?) -> WeatherCode? {
        switch code {
        case nil: return nil
        case 0, 1: return .clear       // clear sky, mainly clear
        case 2: return .partlyCloudy   // partly cloudy
        case 3: return .cloudy         // overcast
        case 45, 48: return .fog       // fog, depositing rime fog
        case 51, 53, 55,               // drizzle: light, moderate, dense
             56, 57,                   // freezing drizzle
             61, 63, 65,               // rain: slight, moderate, heavy
             66, 67,                   // freezing rain
             80, 81, 82:               // rain showers
            return .rain
        case 71, 73, 75,               // snowfall
             85, 86:                   // snow showers
            return .snow
        case 77: return .sleet         // snow grains
        case 95, 96, 99: return .thunderstorm
        default: return nil
        }
    }
}
