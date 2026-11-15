//
//  WeatherScene.swift
//  BreezyUnits
//
//  Ported from upstream, by the numbers rather than by eye:
//    ui-weather-view/src/main/res/drawable{,-night}/weather_background_*.xml
//    materialWeatherView/implementor/{Sun,Cloud,Rain,Snow,Hail,Wind,MeteorShower}Implementor.kt
//
//  Upstream's main-screen background is not a blurred wash: it is a three-stop gradient
//  asset chosen by (weather kind, daylight, theme) with a geometric scene drawn on top --
//  circles for cloud, rounded streaks for rain, thin rectangles for wind, rotating squares
//  for the sun, pulsing stars at night. Everything here is the data behind that scene, so
//  the view layer stays dumb and the numbers stay testable.
//

import Foundation

/// The three stops of one `weather_background_*.xml` gradient (angle 270 = top to bottom).
public struct GradientStops: Equatable, Sendable {
    public let start: RGB
    public let center: RGB
    public let end: RGB

    public init(start: RGB, center: RGB, end: RGB) {
        self.start = start
        self.center = center
        self.end = end
    }
}

/// One of the sun's three rotating ray squares (`SunImplementor`).
public struct SunRay: Equatable, Sendable {
    /// Side of the square as a fraction of the view width before rotation.
    public let sizeRatio: Double
    public let alpha: Double
    /// Seconds for a quarter turn: upstream's `90 / (3000 + 1000 * i)` degrees per ms.
    public let quarterTurnSeconds: Double

    public init(sizeRatio: Double, alpha: Double, quarterTurnSeconds: Double) {
        self.sizeRatio = sizeRatio
        self.alpha = alpha
        self.quarterTurnSeconds = quarterTurnSeconds
    }
}

/// One cloud circle: a radius that breathes between `radius` and `radius * peakScale`.
public struct CloudLayer: Equatable, Sendable {
    /// Centre in view-width units.
    public let x: Double
    public let y: Double
    /// Radius in view-width units.
    public let radius: Double
    public let colour: RGB
    public let alpha: Double
    /// Full breathe cycle in seconds.
    public let period: Double
    public let peakScale: Double

    public init(
        x: Double, y: Double, radius: Double, colour: RGB,
        alpha: Double, period: Double, peakScale: Double
    ) {
        self.x = x
        self.y = y
        self.radius = radius
        self.colour = colour
        self.alpha = alpha
        self.period = period
        self.peakScale = peakScale
    }

    /// `Cloud.computeRadius`: linear up to `peakScale` at the half cycle, then back.
    public func radius(at seconds: Double) -> Double {
        guard period > 0 else { return radius }
        let progress = seconds.truncatingRemainder(dividingBy: period) / period
        let fraction = progress < 0.5 ? progress / 0.5 : (1 - progress) / 0.5
        return radius * (1 + (peakScale - 1) * fraction)
    }
}

/// A night star (`CloudImplementor.Star`, `MeteorShowerImplementor.Star`).
public struct Star: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let radius: Double
    public let colour: RGB
    /// Fade in over the first half, out over the second.
    public let period: Double

    public init(x: Double, y: Double, radius: Double, colour: RGB, period: Double) {
        self.x = x
        self.y = y
        self.radius = radius
        self.colour = colour
        self.period = period
    }

    public func alpha(at seconds: Double) -> Double {
        guard period > 0 else { return 1 }
        let progress = seconds.truncatingRemainder(dividingBy: period) / period
        return progress < 0.5 ? progress / 0.5 : (1 - progress) / 0.5
    }
}

/// A falling or drifting particle, positioned analytically so nothing has to be stepped.
public struct FallingParticle: Equatable, Sendable {
    public enum Shape: String, Sendable {
        /// Rain, sleet and hail: a rounded streak.
        case streak
        /// Snow: a circle.
        case flake
        /// Wind: a long thin rectangle.
        case gust
    }

    public let shape: Shape
    public let colour: RGB
    /// Start offset along the travel axis, in points.
    public let offset: Double
    /// Cross-axis position, in points.
    public let cross: Double
    /// Travel speed in points per second.
    public let speed: Double
    /// Long dimension in points.
    public let length: Double
    /// Short dimension (streak width, flake diameter) in points.
    public let thickness: Double
    /// Rotation of the streak, in degrees.
    public let angle: Double

    public init(
        shape: Shape, colour: RGB, offset: Double, cross: Double, speed: Double,
        length: Double, thickness: Double, angle: Double
    ) {
        self.shape = shape
        self.colour = colour
        self.offset = offset
        self.cross = cross
        self.speed = speed
        self.length = length
        self.thickness = thickness
        self.angle = angle
    }

    /// Position at `seconds`, wrapped into the travel span.
    /// Downward for rain/snow/hail, rightward for wind.
    public func position(at seconds: Double, span: Double) -> Double {
        let travel = span + length
        let raw = (offset + speed * seconds).truncatingRemainder(dividingBy: travel)
        let positive = raw < 0 ? raw + travel : raw
        return positive - length
    }
}

public enum WeatherScene {
    // MARK: - Gradient

    /// `WeatherImplementorFactory.getBackgroundId` plus the `-night` qualifier override.
    public static func gradient(_ kind: WeatherKind, daylight: Bool, darkMode: Bool) -> GradientStops {
        switch kind {
        case .clear where daylight:
            return darkMode ? Self.clearDayNight : Self.clearDay
        case .clear:
            return Self.clearNight
        case .cloud:
            return darkMode ? Self.partlyCloudyNight : Self.partlyCloudy
        case .cloudy:
            return darkMode ? Self.cloudyNight : Self.cloudy
        case .fog:
            return darkMode ? Self.fogNight : Self.fog
        case .haze:
            return darkMode ? Self.hazeNight : Self.haze
        case .rain:
            return darkMode ? Self.rainNight : Self.rain
        case .sleet:
            return darkMode ? Self.sleetNight : Self.sleet
        case .snow:
            return darkMode ? Self.snowNight : Self.snow
        case .hail:
            return darkMode ? Self.hailNight : Self.hail
        case .thunder, .thunderstorm:
            return darkMode ? Self.thunderNight : Self.thunder
        case .wind:
            return darkMode ? Self.windNight : Self.wind
        }
    }

    public static let clearDay = GradientStops(
        start: RGB(hex: 0xFFBA5E), center: RGB(hex: 0xFFC67E), end: RGB(hex: 0xFFF0E2))
    public static let clearNight = GradientStops(
        start: RGB(hex: 0x171D52), center: RGB(hex: 0x3F4DBA), end: RGB(hex: 0x5E68BD))
    public static let partlyCloudy = GradientStops(
        start: RGB(hex: 0x64DBFF), center: RGB(hex: 0xD6DEE0), end: RGB(hex: 0xE2F0F6))
    public static let cloudy = GradientStops(
        start: RGB(hex: 0xAFBCC7), center: RGB(hex: 0xD2D6DB), end: RGB(hex: 0xEBEFF8))
    public static let fog = GradientStops(
        start: RGB(hex: 0xA2C3FF), center: RGB(hex: 0xB3AFD1), end: RGB(hex: 0xE7BEB0))
    public static let haze = GradientStops(
        start: RGB(hex: 0xFFDDA1), center: RGB(hex: 0xD1C3AF), end: RGB(hex: 0xB5E8EF))
    public static let rain = GradientStops(
        start: RGB(hex: 0x97B6D1), center: RGB(hex: 0xA6BBCE), end: RGB(hex: 0x97A8D7))
    public static let sleet = GradientStops(
        start: RGB(hex: 0xB4D3ED), center: RGB(hex: 0xC5D2DC), end: RGB(hex: 0xADC3DE))
    public static let snow = GradientStops(
        start: RGB(hex: 0x93A2AD), center: RGB(hex: 0xE3E7EB), end: RGB(hex: 0xEDF2F6))
    public static let hail = GradientStops(
        start: RGB(hex: 0xDDF7FF), center: RGB(hex: 0xE1E5E9), end: RGB(hex: 0xA0AFC1))
    public static let thunder = GradientStops(
        start: RGB(hex: 0xC697D7), center: RGB(hex: 0xC1A3CE), end: RGB(hex: 0xAB90DB))
    public static let wind = GradientStops(
        start: RGB(hex: 0x96D0A3), center: RGB(hex: 0xDFFAE7), end: RGB(hex: 0xE8F4EE))

    // `drawable-night/` overrides. `clear_night` has none upstream.
    public static let clearDayNight = GradientStops(
        start: RGB(hex: 0x592B19), center: RGB(hex: 0xCC6143), end: RGB(hex: 0xD18268))
    public static let partlyCloudyNight = GradientStops(
        start: RGB(hex: 0x1C2F75), center: RGB(hex: 0x585D6D), end: RGB(hex: 0x747B99))
    public static let cloudyNight = GradientStops(
        start: RGB(hex: 0x23262C), center: RGB(hex: 0x525D66), end: RGB(hex: 0x6B8394))
    public static let fogNight = GradientStops(
        start: RGB(hex: 0x131B45), center: RGB(hex: 0x2A5476), end: RGB(hex: 0x918EAF))
    public static let hazeNight = GradientStops(
        start: RGB(hex: 0x4D3314), center: RGB(hex: 0x755125), end: RGB(hex: 0xC5AF9D))
    public static let rainNight = GradientStops(
        start: RGB(hex: 0x233361), center: RGB(hex: 0x2F4997), end: RGB(hex: 0x252731))
    public static let sleetNight = GradientStops(
        start: RGB(hex: 0x23306B), center: RGB(hex: 0x3549A4), end: RGB(hex: 0x23262F))
    public static let snowNight = GradientStops(
        start: RGB(hex: 0x353A47), center: RGB(hex: 0x455762), end: RGB(hex: 0x414F83))
    public static let hailNight = GradientStops(
        start: RGB(hex: 0x335A7E), center: RGB(hex: 0x435A6F), end: RGB(hex: 0x303742))
    public static let thunderNight = GradientStops(
        start: RGB(hex: 0x2F2B38), center: RGB(hex: 0x50406D), end: RGB(hex: 0x2C1C4D))
    public static let windNight = GradientStops(
        start: RGB(hex: 0x313E3A), center: RGB(hex: 0x529B73), end: RGB(hex: 0x638170))

    // MARK: - Sun

    /// `SunImplementor`: three squares, each 8 rays at 22.5 degrees, turning at
    /// 90/(3000 + 1000i) degrees per millisecond.
    public static let sunRays: [SunRay] = [
        SunRay(sizeRatio: 0.5 * 0.47, alpha: 0.16, quarterTurnSeconds: 3),
        SunRay(sizeRatio: 1.7794 * 0.5 * 0.47, alpha: 0.08, quarterTurnSeconds: 4),
        SunRay(sizeRatio: 3.0594 * 0.5 * 0.47, alpha: 0.04, quarterTurnSeconds: 5)
    ]

    /// `SUN_POSITION`: the sun sits at half the width down, just off the right edge.
    public static let sunPositionRatio = 0.5

    // MARK: - Clouds

    /// `CloudImplementor` TYPE_FOG / TYPE_HAZE: nine circles, three bands, alpha 0.3.
    public static func fogLayers(haze: Bool, daylight: Bool, darkMode: Bool) -> [CloudLayer] {
        let colour = haze
            ? ((daylight && !darkMode) ? RGB(hex: 0xFFDDA1) : RGB(hex: 0x4D3314))
            : ((daylight && !darkMode) ? RGB(hex: 0x93B9FF) : RGB(hex: 0x2A5476))
        return [
            CloudLayer(x: 1.0699, y: 0.38203, radius: 0.42246, colour: colour, alpha: 0.3, period: 9, peakScale: 1.1),
            CloudLayer(x: 0.4866, y: 0.38015, radius: 0.35514, colour: colour, alpha: 0.3, period: 10.5, peakScale: 1.1),
            CloudLayer(x: 0.0351, y: 0.35373, radius: 0.41643, colour: colour, alpha: 0.3, period: 9, peakScale: 1.1),
            CloudLayer(x: 0.8831, y: 0.24161, radius: 0.29142, colour: colour, alpha: 0.3, period: 7, peakScale: 1.15),
            CloudLayer(x: 0.4663, y: 0.21414, radius: 0.26154, colour: colour, alpha: 0.3, period: 8.5, peakScale: 1.15),
            CloudLayer(x: 0.1229, y: 0.20490, radius: 0.26748, colour: colour, alpha: 0.3, period: 7, peakScale: 1.15),
            CloudLayer(x: 0.9250, y: 0.17303, radius: 0.3166, colour: colour, alpha: 0.3, period: 7, peakScale: 1.15),
            CloudLayer(x: 0.4694, y: 0.17295, radius: 0.3166, colour: colour, alpha: 0.3, period: 8.2, peakScale: 1.15),
            CloudLayer(x: 0.0250, y: 0.16705, radius: 0.3166, colour: colour, alpha: 0.3, period: 7.7, peakScale: 1.15)
        ]
    }

    /// `CloudImplementor` TYPE_CLOUDY / TYPE_THUNDER: six circles at alpha 0.3.
    public static func cloudyLayers(thunder: Bool, daylight: Bool, darkMode: Bool) -> [CloudLayer] {
        let colour: RGB
        if thunder {
            colour = (daylight && !darkMode) ? RGB(hex: 0xAB90DB) : RGB(hex: 0x2C1C4D)
        } else {
            colour = (daylight && !darkMode)
                ? RGB(red: 160, green: 179, blue: 191)
                : RGB(red: 95, green: 104, blue: 108)
        }
        return [
            CloudLayer(x: 1.0699, y: 0.38203, radius: 0.42246, colour: colour, alpha: 0.3, period: 9, peakScale: 1.1),
            CloudLayer(x: 0.4866, y: 0.38015, radius: 0.35514, colour: colour, alpha: 0.3, period: 10.5, peakScale: 1.1),
            CloudLayer(x: 0.0351, y: 0.35373, radius: 0.41643, colour: colour, alpha: 0.3, period: 9, peakScale: 1.1),
            CloudLayer(x: 0.8831, y: 0.24161, radius: 0.29142, colour: colour, alpha: 0.3, period: 7, peakScale: 1.15),
            CloudLayer(x: 0.4663, y: 0.21414, radius: 0.26154, colour: colour, alpha: 0.3, period: 8.5, peakScale: 1.15),
            CloudLayer(x: 0.1229, y: 0.20490, radius: 0.26748, colour: colour, alpha: 0.3, period: 7, peakScale: 1.15)
        ]
    }

    /// `CloudImplementor` TYPE_CLOUD: six circles, two alphas (0.40 near, 0.10 far).
    public static func cloudLayers(daylight: Bool, darkMode: Bool) -> [CloudLayer] {
        let colour = (daylight && !darkMode)
            ? RGB(red: 203, green: 245, blue: 255)
            : RGB(red: 151, green: 168, blue: 202)
        return [
            CloudLayer(x: 0.1529, y: 0.13513, radius: 0.2649, colour: colour, alpha: 0.40, period: 7, peakScale: 1.20),
            CloudLayer(x: 0.4793, y: 0.15472, radius: 0.2426, colour: colour, alpha: 0.40, period: 8.5, peakScale: 1.20),
            CloudLayer(x: 0.8531, y: 0.15971, radius: 0.2970, colour: colour, alpha: 0.40, period: 7.05, peakScale: 1.20),
            CloudLayer(x: 0.0551, y: 0.20759, radius: 0.4125, colour: colour, alpha: 0.10, period: 9.5, peakScale: 1.15),
            CloudLayer(x: 0.4928, y: 0.24205, radius: 0.3521, colour: colour, alpha: 0.10, period: 10.5, peakScale: 1.15),
            CloudLayer(x: 1.0499, y: 0.24686, radius: 0.4186, colour: colour, alpha: 0.10, period: 9, peakScale: 1.15)
        ]
    }

    /// The night palette both star fields draw from, in order.
    public static let starColours: [RGB] = [
        RGB(red: 210, green: 247, blue: 255),
        RGB(red: 208, green: 233, blue: 255),
        RGB(red: 175, green: 201, blue: 228),
        RGB(red: 164, green: 194, blue: 220),
        RGB(red: 97, green: 171, blue: 220),
        RGB(red: 74, green: 141, blue: 193),
        RGB(red: 54, green: 66, blue: 119),
        RGB(red: 34, green: 48, blue: 74),
        RGB(red: 236, green: 234, blue: 213),
        RGB(red: 240, green: 220, blue: 151)
    ]

    /// `CloudImplementor`'s star field: 50 stars sized from the diagonal.
    public static func stars(count: Int, width: Double, height: Double, seed: UInt64) -> [Star] {
        var random = SplitMix64(seed: seed)
        let diagonal = (width * width + height * height).squareRoot()
        let radius = 0.00125 * diagonal
        return (0..<count).map { index in
            Star(
                x: random.next(upTo: width),
                y: random.next(upTo: min(height, height * 0.8)),
                radius: radius * (0.7 + 0.3 * random.next(upTo: 1)),
                colour: starColours[index % starColours.count],
                period: 2.5 + 2.5 * random.next(upTo: 1)
            )
        }
    }

    // MARK: - Precipitation

    public enum Precipitation: Sendable {
        case rain, sleet, thunderstorm, snow, hail, wind
    }

    /// Counts straight from the implementors' `COUNT` constants.
    public static func particleCount(_ kind: Precipitation) -> Int {
        switch kind {
        case .rain, .thunderstorm: return 75
        case .sleet: return 45
        case .snow: return 50
        case .hail: return 51
        case .wind: return 160
        }
    }

    /// The three colour bands each implementor assigns by particle index.
    public static func particleColours(_ kind: Precipitation, daylight: Bool) -> [RGB] {
        switch kind {
        case .rain:
            return daylight
                ? [RGB(red: 223, green: 179, blue: 114), RGB(red: 152, green: 175, blue: 222), RGB(red: 255, green: 255, blue: 255)]
                : [RGB(red: 182, green: 142, blue: 82), RGB(red: 88, green: 92, blue: 113), RGB(red: 255, green: 255, blue: 255)]
        case .thunderstorm:
            return daylight
                ? [RGB(red: 182, green: 142, blue: 82), RGB(red: 14, green: 85, blue: 145), RGB(red: 255, green: 255, blue: 255)]
                : [RGB(red: 182, green: 142, blue: 82), RGB(red: 88, green: 92, blue: 113), RGB(red: 255, green: 255, blue: 255)]
        case .sleet, .hail:
            return daylight
                ? [RGB(red: 128, green: 197, blue: 255), RGB(red: 185, green: 222, blue: 255), RGB(red: 255, green: 255, blue: 255)]
                : [RGB(red: 40, green: 102, blue: 155), RGB(red: 99, green: 144, blue: 182), RGB(red: 255, green: 255, blue: 255)]
        case .snow:
            return daylight
                ? [RGB(red: 190, green: 225, blue: 255), RGB(red: 211, green: 233, blue: 255), RGB(red: 255, green: 255, blue: 255)]
                : [RGB(red: 111, green: 133, blue: 155), RGB(red: 140, green: 161, blue: 182), RGB(red: 255, green: 255, blue: 255)]
        case .wind:
            return daylight
                ? [RGB(hex: 0xC2E4CA), RGB(hex: 0xB2E0BA), RGB(hex: 0xD2F0DA)]
                : [RGB(hex: 0x313E3A), RGB(hex: 0x529B73), RGB(hex: 0x638170)]
        }
    }

    /// The particles for a precipitation kind, laid out over a `width` x `height` view.
    public static func particles(
        _ kind: Precipitation, daylight: Bool, width: Double, height: Double, seed: UInt64
    ) -> [FallingParticle] {
        var random = SplitMix64(seed: seed)
        let diagonal = (width * width + height * height).squareRoot()
        let colours = particleColours(kind, daylight: daylight)
        let count = particleCount(kind)
        let scales: [Double] = [0.6, 0.8, 1.0]

        return (0..<count).map { index in
            let band = index * 3 / count
            let colour = colours[min(band, colours.count - 1)]
            let scale = scales[min(band, scales.count - 1)]

            switch kind {
            case .rain, .sleet, .thunderstorm:
                // `Rain`: width 0.002-0.003 of the diagonal (0.004-0.006 for sleet),
                // height 6-10x the width, speed from the diagonal.
                let widthFactor = kind == .sleet ? 0.006 : 0.003
                let thickness = diagonal * widthFactor * (0.66 + 0.34 * random.next(upTo: 1))
                let length = thickness * (6 + 4 * random.next(upTo: 1))
                let velocity = kind == .sleet ? 3.0 : 5.0
                return FallingParticle(
                    shape: .streak, colour: colour,
                    offset: random.next(upTo: diagonal + length),
                    cross: random.next(upTo: width * 1.2) - width * 0.1,
                    speed: diagonal / (1000 * (1.75 + random.next(upTo: 1))) * velocity,
                    length: length, thickness: thickness, angle: 8
                )
            case .snow:
                let radius = diagonal * (0.005 + 0.007 * random.next(upTo: 1)) * scale
                return FallingParticle(
                    shape: .flake, colour: colour,
                    offset: random.next(upTo: diagonal),
                    cross: random.next(upTo: width),
                    speed: diagonal / (1000 * (2.5 + random.next(upTo: 1))) * 1.5,
                    length: radius * 2, thickness: radius * 2, angle: 0
                )
            case .hail:
                let thickness = diagonal * 0.004 * (0.6 + 0.4 * random.next(upTo: 1))
                let length = thickness * (8 + 4 * random.next(upTo: 1))
                return FallingParticle(
                    shape: .streak, colour: colour,
                    offset: random.next(upTo: diagonal + length),
                    cross: random.next(upTo: width * 1.2) - width * 0.1,
                    speed: diagonal / (1000 * (1.2 + random.next(upTo: 1))) * 6,
                    length: length, thickness: thickness, angle: 10
                )
            case .wind:
                let thickness = diagonal * (0.005 + 0.002 * random.next(upTo: 1))
                let length = thickness * (6 + 4 * random.next(upTo: 1))
                return FallingParticle(
                    shape: .gust, colour: colour,
                    offset: random.next(upTo: diagonal),
                    cross: random.next(upTo: height),
                    speed: diagonal / (1000 * (0.5 + random.next(upTo: 1))) * 6,
                    length: length, thickness: thickness, angle: 0
                )
            }
        }
    }
}

/// A deterministic generator, so a scene is identical on every launch and in every test.
struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func nextUInt64() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, bound).
    mutating func next(upTo bound: Double) -> Double {
        guard bound > 0 else { return 0 }
        return Double(nextUInt64() >> 11) / Double(1 << 53) * bound
    }
}
