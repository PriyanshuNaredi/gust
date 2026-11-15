//
//  SettingsScreen.swift
//  Gust
//
//  Upstream's settings root, ported for the parts iOS can honour.
//
//  Android's root is a list of cards: Background updates, Appearance, Main screen,
//  Notifications, External modules, Location, Weather sources, Debug — each with an
//  icon, a title and a one-line summary. Two of those (Notifications, External modules)
//  have no iOS equivalent in this port and are omitted with the reason recorded in
//  SCOPE.md, not replaced with switches that do nothing.
//

import BreezyUnits
import SwiftUI

struct SettingsScreen: View {
    @Environment(AppState.self) private var appState
    /// Set when the screen is presented as a sheet: it owns its navigation stack, so
    /// the dismiss button has to live here rather than in the presenter.
    var onDone: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        BackgroundUpdatesSettings()
                    } label: {
                        PreferenceRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Background updates",
                            subtitle: "Refresh interval, manual refresh"
                        )
                    }
                    .accessibilityIdentifier("settings.background")
                }

                Section {
                    NavigationLink {
                        AppearanceSettings()
                    } label: {
                        PreferenceRow(
                            icon: "paintpalette",
                            title: "Appearance",
                            subtitle: "Theme, units, clock"
                        )
                    }
                    .accessibilityIdentifier("settings.appearance")

                    NavigationLink {
                        MainScreenSettings()
                    } label: {
                        PreferenceRow(
                            icon: "house",
                            title: "Main screen",
                            subtitle: "Blocks displayed, order"
                        )
                    }
                    .accessibilityIdentifier("settings.main")
                }

                Section {
                    NavigationLink {
                        LocationsScreen()
                    } label: {
                        PreferenceRow(
                            icon: "mappin.and.ellipse",
                            title: "Location",
                            subtitle: "Saved places, default location"
                        )
                    }
                    .accessibilityIdentifier("settings.location")

                    NavigationLink {
                        SourcesScreen()
                    } label: {
                        PreferenceRow(
                            icon: "building.2",
                            title: "Weather sources",
                            subtitle: "Provider for each data type"
                        )
                    }
                    .accessibilityIdentifier("settings.sources")
                }

                Section {
                    NavigationLink {
                        DebugScreen()
                    } label: {
                        PreferenceRow(
                            icon: "ladybug",
                            title: "Debug",
                            subtitle: "Diagnostics, live values"
                        )
                    }
                    .accessibilityIdentifier("settings.debug")

                    NavigationLink {
                        LicencesScreen()
                    } label: {
                        PreferenceRow(
                            icon: "doc.text",
                            title: "Licences and notices",
                            subtitle: "LGPL-3.0, Open-Meteo attribution"
                        )
                    }
                    .accessibilityIdentifier("settings.licences")
                } footer: {
                    Text("Gust 0.2.1 · a port of Breezy Weather 6.2.2, not an official release.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if let onDone {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done", action: onDone)
                            .accessibilityIdentifier("settings.done")
                    }
                }
            }
        }
    }
}

/// Upstream's `PreferenceViewWithCard`: icon, bold title, lighter summary.
struct PreferenceRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Appearance

struct AppearanceSettings: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        Form {
            Section("Theme") {
                Picker("Theme", selection: $state.theme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.theme")
            }

            Section("Background") {
                Toggle("Animated background", isOn: $state.animateBackdrop)
                    .accessibilityIdentifier("settings.animateBackdrop")
            }

            Section("Units") {
                Picker("Temperature", selection: $state.units.temperature) {
                    Text("Celsius (°C)").tag(DisplayUnit.celsius)
                    Text("Fahrenheit (°F)").tag(DisplayUnit.fahrenheit)
                }
                .accessibilityIdentifier("settings.temperature")

                Picker("Wind speed", selection: $state.units.speed) {
                    Text("km/h").tag(DisplayUnit.kilometersPerHour)
                    Text("m/s").tag(DisplayUnit.metersPerSecond)
                    Text("mph").tag(DisplayUnit.milesPerHour)
                    Text("knots").tag(DisplayUnit.knots)
                    Text("Beaufort").tag(DisplayUnit.beaufort)
                }

                Picker("Pressure", selection: $state.units.pressure) {
                    Text("hPa").tag(DisplayUnit.hectopascals)
                    Text("mmHg").tag(DisplayUnit.millimetersOfMercury)
                    Text("inHg").tag(DisplayUnit.inchesOfMercury)
                }

                Picker("Precipitation", selection: $state.units.precipitation) {
                    Text("Millimetres").tag(DisplayUnit.millimeters)
                    Text("Inches").tag(DisplayUnit.inches)
                }

                Picker("Distance", selection: $state.units.distance) {
                    Text("Kilometres").tag(DisplayUnit.kilometers)
                    Text("Miles").tag(DisplayUnit.miles)
                    Text("Metres").tag(DisplayUnit.meters)
                }
            }

            Section("Clock") {
                Toggle("12-hour clock", isOn: $state.units.twelveHourClock)
            }
        }
        .navigationTitle("Appearance")
    }
}

// MARK: - Main screen

struct MainScreenSettings: View {
    @Environment(AppState.self) private var appState

    /// The cards a user may hide. The header and footer are excluded: one identifies
    /// the place, the other carries the attribution the licence requires.
    private let hideable: [MainCardKind] = [
        .precipitationNowcast, .daily, .hourly, .precipitation, .wind,
        .airQuality, .pollen, .humidity, .uv, .visibility, .pressure, .sun, .moon, .clock
    ]

    var body: some View {
        @Bindable var state = appState
        Form {
            Section {
                ForEach(hideable, id: \.self) { kind in
                    Toggle(displayName(kind), isOn: Binding(
                        get: { !appState.hiddenCards.contains(kind.rawValue) },
                        set: { visible in
                            if visible {
                                appState.hiddenCards.remove(kind.rawValue)
                            } else {
                                appState.hiddenCards.insert(kind.rawValue)
                            }
                        }
                    ))
                    .accessibilityIdentifier("settings.card.\(kind.rawValue)")
                }
            } header: {
                Text("Blocks displayed")
            } footer: {
                Text("Hiding a block removes it from the main screen. The order matches upstream's.")
            }
        }
        .navigationTitle("Main screen")
    }

    private func displayName(_ kind: MainCardKind) -> String {
        switch kind {
        case .precipitationNowcast: return "Precipitation nowcast"
        case .daily: return "Daily forecast"
        case .hourly: return "Hourly forecast"
        case .airQuality: return "Air quality"
        case .uv: return "UV index"
        case .clock: return "Local time"
        default: return kind.rawValue.capitalized
        }
    }
}

// MARK: - Background updates

struct BackgroundUpdatesSettings: View {
    @Environment(AppState.self) private var appState

    private let intervals = [0, 15, 30, 60, 120]

    var body: some View {
        @Bindable var state = appState
        Form {
            Section {
                Picker("Refresh every", selection: $state.refreshMinutes) {
                    ForEach(intervals, id: \.self) { minutes in
                        Text(minutes == 0 ? "Never" : "\(minutes) minutes").tag(minutes)
                    }
                }
                .accessibilityIdentifier("settings.refreshInterval")
            } footer: {
                Text("iOS does not let an app refresh in the background without a background task; this interval applies while Gust is open.")
            }
        }
        .navigationTitle("Background updates")
    }
}

// MARK: - Weather sources

struct SourcesScreen: View {
    private struct Feature: Identifiable {
        let id: String
        let title: String
        let provider: String
        let note: String
    }

    private let features = [
        Feature(
            id: "forecast", title: "Forecast",
            provider: "Open-Meteo",
            note: "16 days hourly and daily, 15-minute precipitation"
        ),
        Feature(
            id: "airQuality", title: "Air quality",
            provider: "CAMS via Open-Meteo",
            note: "European and global ozone, PM, NO2, SO2, CO"
        ),
        Feature(
            id: "pollen", title: "Pollen",
            provider: "CAMS via Open-Meteo",
            note: "European domain only"
        ),
        Feature(
            id: "geocoding", title: "Place search",
            provider: "Open-Meteo geocoding",
            note: "Names, coordinates and IANA time zones"
        )
    ]

    var body: some View {
        List {
            Section {
                ForEach(features) { feature in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                        Text(feature.provider)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(feature.note)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .accessibilityIdentifier("source.\(feature.id)")
                }
            } footer: {
                Text("""
                Breezy Weather ships 53 provider integrations. This port has one, because each \
                extra provider is a separate parser and a separate set of quirks; the feature \
                pickers exist so adding one later does not change the shape of this screen.
                """)
            }
        }
        .navigationTitle("Weather sources")
    }
}