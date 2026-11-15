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

/// The app's root: the forecast, plus the units playground kept as a second tab.
/// The playground stays because it is the cheapest way to see the ported arithmetic
/// next to the ported service's live output.
struct ContentView: View {
    var body: some View {
        TabView {
            ForecastScreen()
                .tabItem { Label("Weather", systemImage: "cloud.sun") }

            UnitsPlaygroundView()
                .tabItem { Label("Units", systemImage: "ruler") }
        }
    }
}

/// Stage-4 gate, kept as a tab.
struct UnitsPlaygroundView: View {
    // Sample values chosen to exercise the ported computing functions.
    private let temperature = 25.celsius
    private let dewPoint = 18.celsius
    private let humidity = 50.percent
    private let wind = 3.0.metersPerSecond
    private let pressure = 1013.25.hectopascals

    // Live data from the ported client. Berlin, so the values are reproducible for
    // anyone reading this file; the location picker arrives with the locations slice.
    @State private var live: CurrentObservation?
    @State private var liveError: String?

    var body: some View {
        ScrollView {
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

            Text("Live from Open-Meteo (Berlin)")
                .font(.subheadline.weight(.medium))

            row("Temperature", value: liveTemperature, id: "live.temperature")
            row("Wind", value: liveWind, id: "live.wind")
            row("Humidity", value: liveHumidity, id: "live.humidity")
            row("Pressure", value: livePressure, id: "live.pressure")

            Text(liveStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("live.status")

            Divider()

            Text("Stage 5 shell — forecast UI next.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("shell.note")

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            do {
                live = try await OpenMeteoClient().fetchCurrent(latitude: 52.52, longitude: 13.41)
            } catch {
                liveError = String(describing: error)
            }
        }
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

    private var liveStatus: String {
        if let liveError { return "fetch failed: \(liveError)" }
        if live == nil { return "loading…" }
        return "source: Open-Meteo (best_match)"
    }

    private var liveTemperature: String {
        guard let value = live?.temperature else { return "—" }
        return String(format: "%.1f °C", value.inCelsius)
    }

    private var liveWind: String {
        guard let value = live?.wind?.speed else { return "—" }
        return String(format: "%.1f km/h", value.inKilometersPerHour)
    }

    private var liveHumidity: String {
        guard let value = live?.relativeHumidity else { return "—" }
        return String(format: "%.0f %%", value.inPercent)
    }

    private var livePressure: String {
        guard let value = live?.pressure else { return "—" }
        return String(format: "%.1f hPa", value.inHectopascals)
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
