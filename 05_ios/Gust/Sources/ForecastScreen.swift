//
//  ForecastScreen.swift
//  Gust
//
//  The first real main screen: a card stack laid out by the ported CardLayout rule
//  (full-size cards own a row, half-size cards pair two per row), fed by live
//  Open-Meteo data.
//
//  Cards ported so far: header, hourly, daily, and the six half-size cards that
//  need no new model work (wind, humidity, pressure, UV, visibility, sun).
//

import BreezyUnits
import SwiftUI

struct ForecastScreen: View {
    @Environment(AppState.self) private var appState
    @State private var store = ForecastStore()

    /// Which cards the main screen shows, in Android's order. Adding a card here is
    /// the whole change — the layout rule decides its row.
    private let cards: [MainCardKind] = [
        // Upstream's order from ViewType: HEADER, ALERT, PRECIPITATION_NOWCAST,
        // DAILY, HOURLY, then the half-size cards. Daily before hourly is not a
        // mistake here -- it is what the Android main screen does.
        .header, .precipitationNowcast, .daily, .hourly,
        .precipitation, .wind, .airQuality, .pollen, .humidity, .uv, .visibility, .pressure,
        .sun, .moon, .clock, .footer
    ]

    /// Kept so the navigation destination can render a detail page without
    /// re-reading the store's state inside the link.
    private var loadedWeather: Weather? {
        if case .loaded(let weather) = store.state { return weather }
        return nil
    }

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 12) {
                switch store.state {
                case .loading:
                    ProgressView("Loading \(store.place.name)…")
                        .padding(.top, 60)
                        .accessibilityIdentifier("forecast.loading")
                case .failed(let reason):
                    ContentUnavailableView {
                        Label("No weather", systemImage: "cloud.slash")
                    } description: {
                        Text(reason)
                    } actions: {
                        Button("Try again") { Task { await store.reload() } }
                    .accessibilityIdentifier("forecast.retry")
                    }
                    .accessibilityIdentifier("forecast.error")
                case .loaded(let weather):
                    ForEach(Array(CardLayout.rows(for: cards).enumerated()), id: \.offset) { _, row in
                        rowView(row, weather: weather)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
        .navigationDestination(for: MainCardKind.self) { kind in
            if let weather = loadedWeather {
                DetailScreen(kind: kind, weather: weather, units: appState.units)
            }
        }
        .task(id: appState.selectedPlace.id) {
            store.place = appState.selectedPlace
            await store.loadIfNeeded()
        }
        .refreshable {
            store.place = appState.selectedPlace
            await store.reload()
        }
        .accessibilityIdentifier("forecast.screen")
        }
    }

    @ViewBuilder
    private func rowView(_ row: MainCardRow, weather: Weather) -> some View {
        switch row {
        case .full(let kind):
            card(kind, weather: weather)
        case .half(let lhs, let rhs):
            HStack(alignment: .top, spacing: 12) {
                card(lhs, weather: weather)
                card(rhs, weather: weather)
            }
        case .halfAlone(let kind):
            // Half width, not stretched: a lone half card sits beside empty space, as
            // it does in the Android grid.
            HStack(alignment: .top, spacing: 12) {
                card(kind, weather: weather)
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func card(_ kind: MainCardKind, weather: Weather) -> some View {
        if kind.hasDetail {
            NavigationLink(value: kind) {
                cardBody(kind, weather: weather)
            }
            .buttonStyle(.plain)
            // Without this the link becomes a single accessibility element and every
            // card identifier inside it disappears -- the same trap as the container
            // identifiers, one level up.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cardLink.\(kind.rawValue)")
        } else {
            cardBody(kind, weather: weather)
        }
    }

    @ViewBuilder
    private func cardBody(_ kind: MainCardKind, weather: Weather) -> some View {
        switch kind {
        case .header: HeaderCard(weather: weather, place: store.place.name, units: appState.units)
        case .precipitationNowcast: NowcastCard(nowcast: Nowcast(steps: weather.minutelyForecast), zone: weather.timeZone)
        case .precipitation: PrecipitationCard(weather: weather, units: appState.units)
        case .hourly: HourlyCard(weather: weather, units: appState.units)
        case .daily: DailyCard(weather: weather, units: appState.units)
        case .airQuality: MetricHalfCard(title: "Air quality", icon: "aqi.medium", lines: airQualityLines(weather))
        case .pollen: MetricHalfCard(title: "Pollen", icon: "leaf", lines: pollenLines(weather))
        case .wind: MetricHalfCard(title: "Wind", icon: "wind", lines: windLines(weather))
        case .humidity: MetricHalfCard(title: "Humidity", icon: "humidity", lines: humidityLines(weather))
        case .pressure: MetricHalfCard(title: "Pressure", icon: "gauge", lines: pressureLines(weather))
        case .uv: MetricHalfCard(title: "UV index", icon: "sun.max", lines: uvLines(weather))
        case .visibility: MetricHalfCard(title: "Visibility", icon: "eye", lines: visibilityLines(weather))
        case .sun: SunCard(weather: weather)
        case .moon: MoonCard(weather: weather)
        case .clock: ClockCard(timeZone: weather.timeZone)
        case .footer: FooterCard(weather: weather, place: store.place.name)
        default:
            // Cards not ported yet render as nothing rather than as an empty box.
            EmptyView()
        }
    }

    // MARK: - Card content

    private func windLines(_ weather: Weather) -> [String] {
        guard let wind = weather.current?.wind else { return ["—"] }
        var lines: [String] = []
        if let speed = wind.speed { lines.append(appState.units.string(speed)) }
        if let direction = wind.direction { lines.append("\(Int(direction.rounded()))°") }
        if let gusts = wind.gusts { lines.append("gusts " + appState.units.string(gusts)) }
        return lines.isEmpty ? ["—"] : lines
    }

    private func airQualityLines(_ weather: Weather) -> [String] {
        guard let air = weather.airQuality(near: weather.current?.date ?? Date()),
              let index = air.index else { return ["—"] }
        // Upstream names five bands over the same thresholds we ported.
        let names = ["Good", "Fair", "Poor", "Very poor", "Excessive", "Extreme"]
        let level = PollutantIndex.level(forIndex: index) ?? 0
        var lines = ["\(index)", names[min(level, names.count - 1)]]
        if let pm25 = air.pm25 {
            lines.append(String(format: "PM2.5 %.1f", pm25.microgramsPerCubicMeter))
        }
        return lines
    }

    private func pollenLines(_ weather: Weather) -> [String] {
        guard !weather.pollen.isEmpty else {
            // Say why it is empty: outside CAMS's domain there is no data at all,
            // which is not the same as clean air.
            return ["—", "no coverage here"]
        }
        guard let pollen = weather.pollen(near: weather.current?.date ?? Date()) else { return ["—"] }
        guard let dominant = pollen.dominant, dominant.value > 0 else {
            return ["0", "none detected"]
        }
        return [
            String(format: "%.0f", dominant.value),
            dominant.type.rawValue.capitalized
        ]
    }

    private func humidityLines(_ weather: Weather) -> [String] {
        guard let humidity = weather.current?.relativeHumidity else { return ["—"] }
        var lines = [String(format: "%.0f %%", humidity.inPercent)]
        if let dewPoint = weather.current?.dewPoint {
            lines.append("dew " + appState.units.string(dewPoint))
        }
        return lines
    }

    private func pressureLines(_ weather: Weather) -> [String] {
        guard let pressure = weather.current?.pressure else { return ["—"] }
        return [appState.units.string(pressure)]
    }

    private func uvLines(_ weather: Weather) -> [String] {
        guard let uv = weather.current?.uvIndex else { return ["—"] }
        return [String(format: "%.1f", uv)]
    }

    private func visibilityLines(_ weather: Weather) -> [String] {
        guard let visibility = weather.current?.visibility else { return ["—"] }
        return [appState.units.string(visibility)]
    }

    private func legacySunLines(_ weather: Weather) -> [String] {
        guard let today = weather.dailyForecast.first else { return ["—"] }
        var lines: [String] = []
        if let sunshine = today.sunshineDuration {
            lines.append("\(Int((sunshine / 3600).rounded())) h")
        }
        if let uvMax = today.uvIndexMax { lines.append(String(format: "UV max %.1f", uvMax)) }
        return lines.isEmpty ? ["—"] : lines
    }
}
