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
    @State private var showLocations = false
    @State private var showSettings = false
    @State private var showLicences = false
    @State private var showMore = false

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

    /// What the user chose to see. Header and footer are never hideable.
    private var visibleCards: [MainCardKind] {
        cards.filter { kind in
            kind == .header || kind == .footer || !appState.hiddenCards.contains(kind.rawValue)
        }
    }

    /// Black on the pale day colours, white on the darkened night ones -- the same
    /// rule the header text uses.
    private var toolbarForeground: Color {
        (loadedWeather?.isDaylight() ?? true) ? .black.opacity(0.86) : .white
    }

    /// `-backdropKind <name> [-backdropNight]` pins the scene for screenshots: every
    /// other path would need the weather to cooperate. Never set by the app itself.
    private var backdropOverride: (kind: WeatherKind, daylight: Bool)? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-backdropKind"),
              arguments.indices.contains(flag + 1),
              let kind = WeatherKind(rawValue: arguments[flag + 1])
        else { return nil }
        return (kind, !arguments.contains("-backdropNight"))
    }

    /// Kept so the navigation destination can render a detail page without
    /// re-reading the store's state inside the link.
    private var loadedWeather: Weather? {
        if case .loaded(let weather) = store.state { return weather }
        return nil
    }

    var body: some View {
        NavigationStack {
        ZStack {
            // Upstream paints the weather colour behind the whole main screen, not
            // just behind the header card -- the header is transparent on top of it.
            if let weather = loadedWeather {
                WeatherBackdropView(
                    kind: backdropOverride?.kind
                        ?? WeatherBackdrop.kind(for: weather.current?.weatherCode ?? .cloudy),
                    daylight: backdropOverride?.daylight ?? weather.isDaylight(),
                    animated: appState.animateBackdrop
                )
            }
        ScrollView {
            VStack(spacing: 8) {
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
                    ForEach(Array(CardLayout.rows(for: visibleCards).enumerated()), id: \.offset) { _, row in
                        rowView(row, weather: weather)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.clear)
        .navigationBarTitleDisplayMode(.inline)
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
        .task(id: appState.refreshMinutes) {
            // Foreground refresh loop. iOS will suspend the timer when the app is
            // backgrounded, which is exactly the behaviour the settings screen says.
            guard appState.refreshMinutes > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(appState.refreshMinutes * 60))
                guard !Task.isCancelled else { return }
                await store.reload()
            }
        }
        .accessibilityIdentifier("forecast.screen")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showLocations = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .tint(toolbarForeground)
                .accessibilityLabel("Locations")
                .accessibilityIdentifier("header.menu")
            }
            ToolbarItem(placement: .principal) {
                // Explicit colour rather than toolbarColorScheme: the scheme is
                // applied before the weather loads and stays black, which is unreadable
                // on a night backdrop.
                Text(store.place.name)
                    .font(.headline)
                    .foregroundStyle(toolbarForeground)
                    .accessibilityIdentifier("header.place")
            }
            ToolbarItem(placement: .topBarTrailing) {
                // A `Menu` in the navigation bar is unreliable to drive from XCUITest
                // (the tap is first treated as a scroll attempt and can fail), so the
                // overflow is a plain button and a confirmation dialog.
                Button {
                    showMore = true
                } label: {
                    Image(systemName: "ellipsis")
                }
                .tint(toolbarForeground)
                .accessibilityLabel("More")
                .accessibilityIdentifier("header.more")
            }
        }
        // The bar is the weather colour, visible at rest and while scrolling: a
        // transparent bar let the place name draw on top of whatever card scrolled
        // under it. (`toolbarBackgroundVisibility` is 18+; the deployment target is 17.)
        // A transparent bar let the place name draw on top of whatever card scrolled
        // under it. A material bar keeps the title legible at any scroll offset on
        // iOS 17: a weather-coloured bar sampled from the loaded forecast is ignored
        // by SwiftUI when the colour arrives after the bar is built, and
        // `toolbarBackgroundVisibility` is 18+ while the deployment target is 17.
        .toolbarBackground(.regularMaterial, for: .navigationBar)
        .confirmationDialog("More", isPresented: $showMore, titleVisibility: .hidden) {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await store.reload() }
            }
            Button("Edit place", systemImage: "pencil") { showLocations = true }
            Button("Settings", systemImage: "gearshape") { showSettings = true }
            Button("Licences", systemImage: "doc.text") { showLicences = true }
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen(onDone: { showSettings = false })
        }
        .sheet(isPresented: $showLicences) {
            NavigationStack {
                LicencesScreen()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showLicences = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showLocations) {
            NavigationStack {
                LocationsScreen()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showLocations = false }
                        }
                    }
            }
        }
        }
    }

    /// Upstream's half-size cells are square (the circular blocks are `1:1`), so a
    /// rect card and a circle card in the same row stand the same height.
    private var halfSide: CGFloat {
        (UIScreen.main.bounds.width - 24 - 8) / 2
    }

    @ViewBuilder
    private func rowView(_ row: MainCardRow, weather: Weather) -> some View {
        switch row {
        case .full(let kind):
            card(kind, weather: weather)
        case .half(let lhs, let rhs):
            HStack(alignment: .top, spacing: 8) {
                card(lhs, weather: weather)
                    .frame(width: halfSide, height: halfSide)
                card(rhs, weather: weather)
                    .frame(width: halfSide, height: halfSide)
            }
        case .halfAlone(let kind):
            // Half width, not stretched: a lone half card sits beside empty space, as
            // it does in the Android grid.
            HStack(alignment: .top, spacing: 8) {
                card(kind, weather: weather)
                    .frame(width: halfSide, height: halfSide)
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
        case .precipitationNowcast:
            NowcastCard(
                nowcast: Nowcast(steps: weather.minutelyForecast).relative(to: Date()),
                zone: weather.timeZone,
                daylight: weather.isDaylight(),
                currentIsWet: weather.currentIsWet
            )
        case .precipitation: PrecipitationCard(weather: weather, units: appState.units)
        case .hourly: HourlyCard(weather: weather, units: appState.units)
        case .daily: DailyCard(weather: weather, units: appState.units)
        case .airQuality: AirQualityCard(weather: weather)
        case .pollen: PollenCard(weather: weather)
        case .wind: WindCard(weather: weather, units: appState.units)
        case .humidity: MetricHalfCard(title: "Humidity", icon: "humidity", lines: humidityLines(weather))
        case .pressure: MetricHalfCard(title: "Pressure", icon: "gauge", lines: pressureLines(weather), shape: .circle)
        case .uv: MetricHalfCard(title: "UV index", icon: "sun.max", lines: uvLines(weather))
        case .visibility: MetricHalfCard(title: "Visibility", icon: "eye", lines: visibilityLines(weather), shape: .circle)
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
        // Bands from `UV.kt`: <3 low, <6 moderate, <8 high, <11 very high, else extreme.
        let level: String
        switch uv {
        case ..<3: level = "Low"
        case ..<6: level = "Moderate"
        case ..<8: level = "High"
        case ..<11: level = "Very high"
        default: level = "Extreme"
        }
        return [String(format: "%.1f", uv), level]
    }

    private func visibilityLines(_ weather: Weather) -> [String] {
        guard let visibility = weather.current?.visibility else { return ["—"] }
        // Thresholds from `UnitExtensions.kt` (metres).
        let metres = visibility.inMeters
        let quality: String
        switch metres {
        case ..<1_000: quality = "Very poor"
        case ..<4_000: quality = "Poor"
        case ..<10_000: quality = "Moderate"
        case ..<20_000: quality = "Good"
        case ..<40_000: quality = "Clear"
        default: quality = "Perfectly clear"
        }
        return [appState.units.string(visibility), quality]
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
