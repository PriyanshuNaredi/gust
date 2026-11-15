//
//  WeatherBackdropView.swift
//  Gust
//
//  The main screen's background: upstream's per-weather colour, a vertical gradient
//  out of it, and a few soft shapes so the screen is not a flat wash. The animated
//  rain/snow artwork upstream draws is its own illustration and is not copied; the
//  colour table and the day/night rule are, and they do most of the work.
//

import BreezyUnits
import SwiftUI

private extension RGB {
    func swiftUIColor(overlay other: RGB) -> Color {
        Color(red: other.red / 255, green: other.green / 255, blue: other.blue / 255)
    }
}

struct WeatherBackdropView: View {
    let kind: WeatherKind
    let daylight: Bool

    var body: some View {
        let base = WeatherBackdrop.backgroundColor(kind, daylight: daylight)
        let top = mix(base, towards: daylight ? 1 : 0, amount: daylight ? 0.55 : 0.30)
        ZStack {
            LinearGradient(
                colors: [base.swiftUIColor(overlay: top), Color(red: base.red / 255, green: base.green / 255, blue: base.blue / 255)],
                startPoint: .top,
                endPoint: .bottom
            )
            shapes(base: base)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("backdrop")
    }

    @ViewBuilder
    private func shapes(base: RGB) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                switch kind {
                case .clear, .haze:
                    Circle()
                        .fill(Color.white.opacity(daylight ? 0.35 : 0.08))
                        .frame(width: size.width * 0.9)
                        .blur(radius: 60)
                        .offset(x: size.width * 0.15, y: -size.height * 0.35)
                case .wind:
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: size.width * 0.8, height: 10)
                            .offset(x: CGFloat(index - 1) * size.width * 0.12, y: size.height * (0.1 + 0.09 * CGFloat(index)))
                    }
                default:
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: size.width * (0.75 - 0.12 * CGFloat(index)))
                            .offset(
                                x: size.width * (index.isMultiple(of: 2) ? 0.22 : -0.2),
                                y: -size.height * 0.36 + CGFloat(index) * 42
                            )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Linear mix towards white (day) or black (night), done in components so the
    /// result is a plain colour and not a compositing stack.
    private func mix(_ base: RGB, towards target: Double, amount: Double) -> RGB {
        func blend(_ value: Double) -> Double { value * (1 - amount) + target * 255 * amount }
        return RGB(red: blend(base.red), green: blend(base.green), blue: blend(base.blue))
    }
}
