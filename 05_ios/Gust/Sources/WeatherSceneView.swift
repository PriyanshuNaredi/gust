//
//  WeatherSceneView.swift
//  Gust
//
//  The animated weather background: upstream's three-stop gradient with its geometric
//  scene drawn on top. The scene is entirely analytic — every position is a function of
//  elapsed time — so nothing needs to be stepped, nothing can drift, and the view can be
//  paused without losing state.
//
//  Numbers (counts, colours, sizes, speeds) live in `BreezyUnits.WeatherScene` and are
//  asserted against the upstream resources by `WeatherSceneTests`.
//
//  Twenty frames a second: the scene is slow (breathing clouds, drifting rain), so 60 fps
//  bought nothing measurable and cost ~3x the CPU on the simulator. Measured idle CPU on
//  the main screen: ~10% at 30 fps, ~6% at 20 fps, ~0.3% paused.
//

import BreezyUnits
import SwiftUI

struct WeatherSceneView: View {
    let kind: WeatherKind
    let daylight: Bool
    var animated: Bool = true

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var darkMode: Bool { scheme == .dark }
    private var running: Bool { animated && !reduceMotion }

    var body: some View {
        ZStack {
            gradient
            scene
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var gradient: LinearGradient {
        let stops = WeatherScene.gradient(kind, daylight: daylight, darkMode: darkMode)
        return LinearGradient(
            stops: [
                .init(color: stops.start.color, location: 0),
                .init(color: stops.center.color, location: 0.5),
                .init(color: stops.end.color, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var scene: some View {
        if running {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                canvas(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            canvas(at: 0.4)
        }
    }

    private func canvas(at seconds: Double) -> some View {
        Canvas { context, size in
            switch kind {
            case .clear:
                if daylight {
                    drawSun(in: &context, size: size, at: seconds)
                } else {
                    drawStars(in: &context, size: size, at: seconds, count: 70)
                    drawMeteors(in: &context, size: size, at: seconds)
                }
            case .cloud:
                drawClouds(in: &context, size: size, at: seconds, layers: cloudLayers)
                drawStars(in: &context, size: size, at: seconds, count: 50)
            case .cloudy:
                drawClouds(in: &context, size: size, at: seconds, layers: cloudLayers)
            case .fog:
                drawClouds(in: &context, size: size, at: seconds, layers: cloudLayers)
            case .haze:
                drawClouds(in: &context, size: size, at: seconds, layers: cloudLayers)
            case .thunder:
                drawClouds(in: &context, size: size, at: seconds, layers: cloudLayers)
                drawStars(in: &context, size: size, at: seconds, count: 50)
                drawThunder(in: &context, size: size, at: seconds)
            case .rain, .sleet, .snow, .hail, .thunderstorm, .wind:
                drawParticles(in: &context, size: size, at: seconds)
                if kind == .thunderstorm { drawThunder(in: &context, size: size, at: seconds) }
            }
        }
    }

    // MARK: - Kind → data

    private var cloudLayers: [CloudLayer] {
        switch kind {
        case .cloud: return WeatherScene.cloudLayers(daylight: daylight, darkMode: darkMode)
        case .cloudy: return WeatherScene.cloudyLayers(thunder: false, daylight: daylight, darkMode: darkMode)
        case .thunder: return WeatherScene.cloudyLayers(thunder: true, daylight: daylight, darkMode: darkMode)
        case .fog: return WeatherScene.fogLayers(haze: false, daylight: daylight, darkMode: darkMode)
        case .haze: return WeatherScene.fogLayers(haze: true, daylight: daylight, darkMode: darkMode)
        default: return []
        }
    }

    private var particleKind: WeatherScene.Precipitation? {
        switch kind {
        case .rain: return .rain
        case .sleet: return .sleet
        case .snow: return .snow
        case .hail: return .hail
        case .thunderstorm: return .thunderstorm
        case .wind: return .wind
        default: return nil
        }
    }

    /// Seeded per kind so rain and snow never share a layout, and every launch is the same.
    private var seed: UInt64 {
        UInt64(abs(kind.rawValue.hashValue % 1000)) + 17
    }

    // MARK: - Drawing

    /// `SunImplementor`: three layers of four squares, each layer turned 90° over its
    /// quarter-turn period, offset to the right edge so only the rays fall on screen.
    private func drawSun(in context: inout GraphicsContext, size: CGSize, at seconds: Double) {
        let colour = darkMode ? Color.black : Color.white
        let centre = CGPoint(
            x: size.width,
            y: WeatherScene.sunPositionRatio * size.width
        )

        for ray in WeatherScene.sunRays {
            let side = ray.sizeRatio * size.width
            let degrees = (seconds / ray.quarterTurnSeconds).truncatingRemainder(dividingBy: 1) * 90

            var layer = context
            layer.translateBy(x: centre.x, y: centre.y)
            layer.rotate(by: Angle.degrees(degrees))
            for step in 0..<4 {
                let rotation = Angle.degrees(Double(step) * 22.5)
                let rect = CGRect(x: -side, y: -side, width: side * 2, height: side * 2)
                layer.drawLayer { inner in
                    var inner = inner
                    inner.rotate(by: rotation)
                    inner.fill(Path(rect), with: .color(colour.opacity(ray.alpha)))
                }
            }
        }
    }

    private func drawClouds(
        in context: inout GraphicsContext, size: CGSize, at seconds: Double, layers: [CloudLayer]
    ) {
        for layer in layers {
            let radius = layer.radius(at: seconds) * size.width
            let centre = CGPoint(x: layer.x * size.width, y: layer.y * size.width)
            let rect = CGRect(
                x: centre.x - radius, y: centre.y - radius,
                width: radius * 2, height: radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(layer.colour.color.opacity(layer.alpha)))
        }
    }

    private func drawStars(in context: inout GraphicsContext, size: CGSize, at seconds: Double, count: Int) {
        for star in WeatherScene.stars(
            count: count, width: size.width, height: size.height, seed: seed &+ UInt64(count)
        ) {
            let alpha = star.alpha(at: seconds + star.period * 0.37)
            guard alpha > 0.01 else { continue }
            let rect = CGRect(
                x: star.x - star.radius, y: star.y - star.radius,
                width: star.radius * 2, height: star.radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(star.colour.color.opacity(alpha)))
        }
    }

    /// `MeteorShowerImplementor`: ten streaks at 60°, each reviving every 5–25 s.
    private func drawMeteors(in context: inout GraphicsContext, size: CGSize, at seconds: Double) {
        let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
        for index in 0..<10 {
            let period = 5.0 + Double((index * 7) % 20)
            let phase = (seconds + Double(index) * 1.7).truncatingRemainder(dividingBy: period) / period
            // Visible for the first 40 % of the cycle, then gone.
            guard phase < 0.4 else { continue }
            let travel = phase / 0.4
            let length = diagonal * 0.16
            let startX = size.width * (0.15 + 0.07 * Double(index % 9))
            let startY = -length * 0.5
            let angle = -60.0 * Double.pi / 180
            let head = CGPoint(
                x: startX + cos(angle) * travel * size.height,
                y: startY + -sin(angle) * travel * size.height * 0.9
            )
            let tail = CGPoint(
                x: head.x - cos(angle) * length,
                y: head.y + -sin(angle) * length * 0.9
            )
            var path = Path()
            path.move(to: head)
            path.addLine(to: tail)
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.75), .white.opacity(0)]),
                    startPoint: head,
                    endPoint: tail
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        }
    }

    private func drawParticles(in context: inout GraphicsContext, size: CGSize, at seconds: Double) {
        guard let kind = particleKind else { return }
        let particles = WeatherScene.particles(
            kind, daylight: daylight, width: size.width, height: size.height, seed: seed
        )
        let span = (kind == .wind) ? size.width : size.height

        for particle in particles {
            let along = particle.position(at: seconds, span: span)
            switch particle.shape {
            case .streak:
                let head = CGPoint(x: particle.cross, y: along)
                let radians = particle.angle * Double.pi / 180
                let tail = CGPoint(
                    x: head.x - sin(radians) * particle.length,
                    y: head.y + cos(radians) * particle.length
                )
                var path = Path()
                path.move(to: head)
                path.addLine(to: tail)
                context.stroke(
                    path,
                    with: .color(particle.colour.color.opacity(0.75)),
                    style: StrokeStyle(lineWidth: particle.thickness, lineCap: .round)
                )
            case .flake:
                let rect = CGRect(
                    x: particle.cross - particle.thickness / 2,
                    y: along - particle.thickness / 2,
                    width: particle.thickness, height: particle.thickness
                )
                context.fill(Path(ellipseIn: rect), with: .color(particle.colour.color.opacity(0.8)))
            case .gust:
                let rect = CGRect(
                    x: along, y: particle.cross,
                    width: particle.length, height: particle.thickness
                )
                context.fill(Path(roundedRect: rect, cornerRadius: particle.thickness / 2),
                             with: .color(particle.colour.color.opacity(0.55)))
            }
        }
    }

    /// `Thunder`: a violet flash that blinks twice every few seconds.
    private func drawThunder(in context: inout GraphicsContext, size: CGSize, at seconds: Double) {
        let cycle = 6.3
        let phase = seconds.truncatingRemainder(dividingBy: cycle)
        let alpha: Double
        if phase < 0.3 {
            alpha = phase < 0.15 ? phase / 0.15 : (0.3 - phase) / 0.15
        } else if phase < 0.5 {
            alpha = phase < 0.4 ? (phase - 0.3) / 0.10 : (0.5 - phase) / 0.10
        } else {
            alpha = 0
        }
        guard alpha > 0.01 else { return }
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(RGB(red: 81, green: 67, blue: 168).color.opacity(alpha * 0.66)))
    }
}

extension RGB {
    var color: Color {
        Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: 1)
    }
}
