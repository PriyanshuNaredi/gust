//
//  DebugScreen.swift
//  Gust
//
//  The ported arithmetic, displayed next to live values from the ported client. This
//  began as the stage-4 gate and stays reachable from Settings because it is still the
//  fastest way to answer "is the number I am looking at the ported formula or the
//  source's own?".
//

import BreezyUnits
import SwiftUI

struct DebugScreen: View {
    private let temperature = 25.celsius
    private let dewPoint = 18.celsius
    private let humidity = 50.percent
    private let wind = 3.0.metersPerSecond
    private let pressure = 1013.25.hectopascals

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
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Diagnostics")
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
