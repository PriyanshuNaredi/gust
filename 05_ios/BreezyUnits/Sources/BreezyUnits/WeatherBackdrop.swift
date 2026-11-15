//
//  WeatherBackdrop.swift
//  BreezyUnits
//
//  Ported from upstream:
//    ui-weather-view/.../materialWeatherView/MaterialWeatherThemeDelegate.kt
//    .../implementor/{Sun,Cloud,Rain,Snow,Hail,Wind,MeteorShower}Implementor.kt
//    ui/theme/weatherView/WeatherViewController.kt  (WeatherCode -> WeatherKind)
//
//  Upstream paints an animated weather view behind the main screen and asks the theme
//  delegate for the matching background colour. The animation itself is the app's own
//  artwork and is not ported; the colours and the day/night rule are, exactly, because
//  they are what makes the screen read as "grey-blue drizzle" or "warm summer evening"
//  at a glance.
//

import Foundation

/// Upstream's `WeatherView.WEATHER_KIND_*`, in its numbering order.
public enum WeatherKind: String, CaseIterable, Sendable {
    case clear, cloud, cloudy, fog, haze, rain, sleet, snow
    case hail, thunder, thunderstorm, wind
}

public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Upstream writes these colours as negative ints (`-0x62503f`); this is that.
    public init(androidArgb value: Int) {
        self.red = Double((value >> 16) & 0xFF)
        self.green = Double((value >> 8) & 0xFF)
        self.blue = Double(value & 0xFF)
    }

    public init(hex: UInt32) {
        self.red = Double((hex >> 16) & 0xFF)
        self.green = Double((hex >> 8) & 0xFF)
        self.blue = Double(hex & 0xFF)
    }
}

public enum WeatherBackdrop {
    /// `MeteorShowerImplementor.themeColor` — a clear night.
    public static let clearNight = RGB(red: 20, green: 28, blue: 44)
    /// `SunImplementor.themeColor` — a clear day.
    public static let clearDay = RGB(red: 253, green: 188, blue: 76)

    /// The exact table from `MaterialWeatherThemeDelegate.innerGetBackgroundColor`.
    public static func baseColor(_ kind: WeatherKind, daylight: Bool) -> RGB {
        switch kind {
        case .clear:
            return daylight ? clearDay : clearNight
        case .cloud:
            return daylight ? RGB(androidArgb: -0xff5a27) : RGB(androidArgb: -0xddd2bd)
        case .cloudy:
            return daylight ? RGB(androidArgb: -0x62503f) : RGB(androidArgb: -0xd9cdc8)
        case .fog:
            return daylight ? RGB(androidArgb: -0x5c513e) : RGB(androidArgb: -0xb0a298)
        case .haze:
            return daylight ? RGB(androidArgb: -0x1e3767) : RGB(androidArgb: -0x93a3b7)
        case .rain:
            return daylight ? RGB(androidArgb: -0xbd6819) : RGB(androidArgb: -0xd9b171)
        case .sleet:
            return daylight ? RGB(androidArgb: -0x974501) : RGB(androidArgb: -0xe5a46e)
        case .snow, .hail:
            return daylight ? RGB(androidArgb: -0x974501) : RGB(androidArgb: -0xe5a46e)
        case .thunderstorm:
            return daylight ? RGB(androidArgb: -0x4d6943) : RGB(androidArgb: -0xdce8c7)
        case .thunder:
            return daylight ? RGB(androidArgb: -0x4d6943) : RGB(androidArgb: -0xdce8c7)
        case .wind:
            return daylight ? RGB(androidArgb: -0x15325d) : RGB(androidArgb: -0x6a798b)
        }
    }

    /// `MaterialWeatherThemeDelegate.getBrighterColor`: night colours are lifted so
    /// text stays legible on them — saturation −0.25, value +0.25, both clamped.
    public static func brightened(_ color: RGB) -> RGB {
        let maxComponent = max(color.red, max(color.green, color.blue))
        let minComponent = min(color.red, min(color.green, color.blue))
        let value = maxComponent / 255
        let saturation = maxComponent == 0 ? 0 : (maxComponent - minComponent) / maxComponent

        let newSaturation = min(max(saturation - 0.25, 0), 1)
        let newValue = min(max(value + 0.25, 0), 1)

        // HSV -> RGB with the standard formula, matching Android's Color.HSVToColor.
        guard newSaturation > 0 else {
            let component = newValue * 255
            return RGB(red: component, green: component, blue: component)
        }
        let hue: Double
        if maxComponent == color.red {
            hue = (60 * ((color.green - color.blue) / (maxComponent - minComponent))).truncatingRemainder(dividingBy: 360)
        } else if maxComponent == color.green {
            hue = 60 * ((color.blue - color.red) / (maxComponent - minComponent)) + 120
        } else {
            hue = 60 * ((color.red - color.green) / (maxComponent - minComponent)) + 240
        }
        let normalizedHue = hue < 0 ? hue + 360 : hue
        let sector = normalizedHue / 60
        let fraction = sector - floor(sector)
        let p = newValue * (1 - newSaturation)
        let q = newValue * (1 - newSaturation * fraction)
        let t = newValue * (1 - newSaturation * (1 - fraction))
        let (r, g, b): (Double, Double, Double)
        switch Int(floor(sector)) % 6 {
        case 0: (r, g, b) = (newValue, t, p)
        case 1: (r, g, b) = (q, newValue, p)
        case 2: (r, g, b) = (p, newValue, t)
        case 3: (r, g, b) = (p, q, newValue)
        case 4: (r, g, b) = (t, p, newValue)
        default: (r, g, b) = (newValue, p, q)
        }
        return RGB(red: r * 255, green: g * 255, blue: b * 255)
    }

    /// The colour actually used: upstream brightens only the night colours.
    public static func backgroundColor(_ kind: WeatherKind, daylight: Bool) -> RGB {
        let color = baseColor(kind, daylight: daylight)
        return daylight ? color : brightened(color)
    }

    /// `WeatherViewController.getWeatherKind`: Breezy code -> kind.
    public static func kind(for code: WeatherCode) -> WeatherKind {
        switch code {
        case .clear: return .clear
        case .partlyCloudy: return .cloud
        case .cloudy: return .cloudy
        case .rain: return .rain
        case .snow: return .snow
        case .wind: return .wind
        case .fog: return .fog
        case .haze: return .haze
        case .sleet: return .sleet
        case .hail: return .hail
        case .thunder: return .thunder
        case .thunderstorm: return .thunderstorm
        default: return .cloudy
        }
    }
}
