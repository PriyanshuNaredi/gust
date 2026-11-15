//
//  WeatherIcons.swift
//  BreezyUnits
//
//  Upstream does not switch on a code to pick a picture; it builds a resource name
//  (`Constants.getResourcesName(code) + "_" + day|night`) and lets a filter map the
//  missing day/night variants onto the shared artwork
//  (`res/xml/icon_provider_drawable_filter.xml`). Ported here as a pure function so
//  the mapping is testable without a screen, and so a missing name fails a test
//  instead of drawing an empty square.
//

import Foundation

public enum WeatherIcons {
    public enum MiniStyle: String, Sendable {
        case light, grey, dark
    }

    /// Upstream's `RESOURCES_*` names. Only `clear` and `partly_cloudy` have
    /// separate day/night artwork; the rest are shared, which is exactly what the
    /// drawable filter expresses.
    private static func base(_ code: WeatherCode) -> String {
        switch code {
        case .clear: return "clear"
        case .partlyCloudy: return "partly_cloudy"
        case .cloudy: return "cloudy"
        case .rain: return "rain"
        case .snow: return "snow"
        case .wind: return "wind"
        case .fog: return "fog"
        case .haze: return "haze"
        case .sleet: return "sleet"
        case .hail: return "hail"
        case .thunder: return "thunder"
        case .thunderstorm: return "thunderstorm"
        }
    }

    private static func hasDayNightVariants(_ code: WeatherCode) -> Bool {
        code == .clear || code == .partlyCloudy
    }

    /// `weather_clear_day`, `weather_rain`, … — the file name minus `.png`.
    public static func name(for code: WeatherCode, day: Bool) -> String {
        let base = base(code)
        guard hasDayNightVariants(code) else { return "weather_\(base)" }
        return "weather_\(base)_\(day ? "day" : "night")"
    }

    /// The small monochrome-ish variants used inside notification widgets.
    public static func miniName(for code: WeatherCode, day: Bool, style: MiniStyle) -> String {
        "\(name(for: code, day: day))_mini_\(style.rawValue)"
    }

    /// Every artwork name the app can ask for, so a test can check them against the
    /// bundle instead of waiting for a blank icon in a screenshot.
    public static var allNames: [String] {
        WeatherCode.allCases.flatMap { code -> [String] in
            if hasDayNightVariants(code) {
                return [name(for: code, day: true), name(for: code, day: false)]
            }
            return [name(for: code, day: true)]
        }
    }
}
