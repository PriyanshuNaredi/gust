//
//  AppState.swift
//  Gust
//
//  Saved places and display preferences, persisted between launches. Small on
//  purpose: two JSON blobs (places, prefs) and the id of the selected one.
//
//  The default place is Berlin so a fresh install can render immediately, and so the
//  recorded test fixtures match what the app is showing.
//

import BreezyUnits
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class AppState {
    private static let preferencesKey = "gust.units.v1"
    private static let themeKey = "gust.theme.v1"
    private static let hiddenCardsKey = "gust.hiddenCards.v1"
    private static let refreshKey = "gust.refreshMinutes.v1"
    private static let animateBackdropKey = "gust.animateBackdrop.v1"
    private static let placesFile = "places.json"

    /// Berlin, matching the fixtures the package tests use.
    static let defaultPlace = Place(
        id: 2950159,
        name: "Berlin",
        latitude: 52.52437,
        longitude: 13.41053,
        country: "Germany",
        admin1: "State of Berlin",
        timezone: "Europe/Berlin"
    )

    var units: UnitPreferences {
        didSet { persistUnits() }
    }

    /// Appearance and main-screen display, both persisted like the units.
    var theme: AppTheme = .system {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }

    /// Cards the user hid. Header and footer are not optional: the screen needs a
    /// header to identify the place, and the footer carries the attribution.
    var hiddenCards: Set<String> = [] {
        didSet { UserDefaults.standard.set(Array(hiddenCards), forKey: Self.hiddenCardsKey) }
    }

    /// Upstream's Appearance > "Animated background". Off means the scene is drawn once,
    /// which is also the setting a user with an older phone will reach for.
    var animateBackdrop: Bool = true {
        didSet { UserDefaults.standard.set(animateBackdrop, forKey: Self.animateBackdropKey) }
    }

    /// Minutes between automatic refreshes. 0 disables it.
    var refreshMinutes: Int = 30 {
        didSet { UserDefaults.standard.set(refreshMinutes, forKey: Self.refreshKey) }
    }

    private(set) var places: [Place]
    private(set) var selectedPlaceID: Int?

    init() {
        let defaults = UserDefaults.standard
        // UI tests pass -resetState. Without this the tests inherit whatever the
        // last manual run left behind, which is how a unit assertion passed in one
        // order and failed in another.
        if ProcessInfo.processInfo.arguments.contains("-resetState") {
            defaults.removeObject(forKey: Self.preferencesKey)
            defaults.removeObject(forKey: "gust.selectedPlace")
            defaults.removeObject(forKey: Self.themeKey)
            defaults.removeObject(forKey: Self.hiddenCardsKey)
            defaults.removeObject(forKey: Self.refreshKey)
            defaults.removeObject(forKey: Self.animateBackdropKey)
            try? FileManager.default.removeItem(
                at: Self.storageDirectory().appendingPathComponent(Self.placesFile)
            )
        }
        if let data = defaults.data(forKey: Self.preferencesKey),
           let decoded = try? JSONDecoder().decode(UnitPreferences.self, from: data) {
            units = decoded
        } else {
            units = UnitPreferences()
        }
        theme = AppTheme(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .system
        hiddenCards = Set(defaults.stringArray(forKey: Self.hiddenCardsKey) ?? [])
        refreshMinutes = defaults.object(forKey: Self.refreshKey) as? Int ?? 30
        animateBackdrop = defaults.object(forKey: Self.animateBackdropKey) as? Bool ?? true
        let stored = Self.loadPlaces()
        places = stored.isEmpty ? [Self.defaultPlace] : stored
        selectedPlaceID = defaults.object(forKey: "gust.selectedPlace") as? Int ?? places.first?.id
    }

    var selectedPlace: Place {
        places.first { $0.id == selectedPlaceID } ?? places.first ?? Self.defaultPlace
    }

    // MARK: - Places

    func select(_ place: Place) {
        selectedPlaceID = place.id
        UserDefaults.standard.set(place.id, forKey: "gust.selectedPlace")
    }

    /// Adding an existing place selects it instead of duplicating it, which keeps
    /// saved-place ids unique (they are the identity a user expects to persist).
    func add(_ place: Place) {
        if !places.contains(where: { $0.id == place.id }) {
            places.append(place)
            persistPlaces()
        }
        select(place)
    }

    func remove(_ place: Place) {
        // Never leave the list empty: a weather app with no place has nothing to show.
        guard places.count > 1 else { return }
        places.removeAll { $0.id == place.id }
        persistPlaces()
        if selectedPlaceID == place.id, let first = places.first {
            select(first)
        }
    }

    // MARK: - Persistence

    private func persistUnits() {
        guard let data = try? JSONEncoder().encode(units) else { return }
        UserDefaults.standard.set(data, forKey: Self.preferencesKey)
    }

    private func persistPlaces() {
        guard let data = try? JSONEncoder().encode(places) else { return }
        let url = Self.storageDirectory().appendingPathComponent(Self.placesFile)
        try? data.write(to: url, options: .atomic)
    }

    private static func storageDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Gust", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func loadPlaces() -> [Place] {
        let url = storageDirectory().appendingPathComponent(placesFile)
        guard let data = try? Data(contentsOf: url),
              let places = try? JSONDecoder().decode([Place].self, from: data) else { return [] }
        return places
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
