//
//  ContentView.swift
//  Gust
//
//  Stage-4 shell. It is deliberately not a forecast screen yet: its job is to
//  prove three things before any real UI exists —
//    1. the app builds and launches on a simulator with no signing identity,
//    2. the local `BreezyUnits` package links and is callable from the app target,
//    3. values rendered here are the ported upstream arithmetic, not placeholders
//       (the numbers match upstream's own test expectations).
//

import SwiftUI
import BreezyUnits

struct ContentView: View {
    // Sample values chosen to exercise the ported computing functions.
    private let temperature = 25.celsius
    private let dewPoint = 18.celsius
    private let humidity = 50.percent
    private let wind = 3.0.metersPerSecond
    private let pressure = 1013.25.hectopascals

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gust")
                .font(.largeTitle.weight(.semibold))
                .accessibilityIdentifier("app.title")

            Text("Port of Breezy Weather 6.2.2 · LGPL-3.0")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider()

            row("Temperature", value: String(format: "%.1f °C", temperature.inCelsius), id: "value.temperature")
            row("Humidex", value: humidexText, id: "value.humidex")
            row("Apparent", value: apparentText, id: "value.apparent")
            row("Wind chill", value: windChillText, id: "value.windchill")
            row("Pressure", value: String(format: "%.2f hPa", pressure.inHectopascals), id: "value.pressure")

            Divider()

            Text("Stage 4 shell — no forecast UI yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("shell.note")

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ label: String, value: String, id: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .monospacedDigit()
                .accessibilityIdentifier(id)
        }
    }

    private var humidexText: String {
        guard let humidex = computeHumidex(temperature: temperature, dewPoint: dewPoint) else { return "—" }
        return String(format: "%.1f °C", humidex.inCelsius)
    }

    private var apparentText: String {
        guard let apparent = computeApparentTemperature(
            temperature: temperature, relativeHumidity: humidity, windSpeed: wind
        ) else { return "—" }
        return String(format: "%.1f °C", apparent.inCelsius)
    }

    private var windChillText: String {
        // nil above 10 °C by design — the UI must show "—", not a fabricated value.
        guard let chill = computeWindChillTemperature(temperature: temperature, windSpeed: wind) else { return "—" }
        return String(format: "%.1f °C", chill.inCelsius)
    }
}

#Preview {
    ContentView()
}
