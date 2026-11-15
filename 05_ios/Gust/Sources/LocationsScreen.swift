//
//  LocationsScreen.swift
//  Gust
//
//  Saved places and search. Ported from Breezy's location management: pick a place,
//  see the main screen for it, remove places you no longer care about. The search
//  itself is Open-Meteo's geocoding endpoint.
//

import BreezyUnits
import SwiftUI

struct LocationsScreen: View {
    @Environment(AppState.self) private var appState
    @State private var isSearching = false

    var body: some View {
            List {
                Section("Saved") {
                    ForEach(appState.places) { place in
                        Button {
                            appState.select(place)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .foregroundStyle(.primary)
                                    if !place.subtitle.isEmpty {
                                        Text(place.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if place.id == appState.selectedPlace.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityIdentifier("place.\(place.id)")
                        .swipeActions {
                            if appState.places.count > 1 {
                                Button("Delete", role: .destructive) {
                                    appState.remove(place)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Locations")
            .toolbar {
                Button {
                    isSearching = true
                } label: {
                    Label("Add place", systemImage: "plus")
                }
                .accessibilityIdentifier("locations.add")
            }
            .sheet(isPresented: $isSearching) {
                // A sheet needs its own navigation container for .searchable and the
                // Cancel button to work; the parent stack does not reach into it.
                NavigationStack {
                    PlaceSearchView { place in
                        appState.add(place)
                        isSearching = false
                    }
                }
            }
    }
}

struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Place) -> Void

    @State private var query = ""
    @State private var results: [Place] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(results) { place in
                    Button {
                        onSelect(place)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .foregroundStyle(.primary)
                            if !place.subtitle.isEmpty {
                                Text(place.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("searchResult.\(place.id)")
                }
                if results.isEmpty && !query.isEmpty && !isSearching && errorMessage == nil {
                    Text("No places match “\(query)”.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if isSearching { ProgressView() }
            }
            .searchable(text: $query, prompt: "City name")
            .onChange(of: query) { _, newValue in
                scheduleSearch(for: newValue)
            }
            .navigationTitle("Add place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }

    /// Debounced: a request per keystroke would hammer a free public service.
    private func scheduleSearch(for text: String) {
        searchTask?.cancel()
        guard text.trimmingCharacters(in: .whitespaces).count >= 2 else {
            results = []
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await runSearch(text)
        }
    }

    private func runSearch(_ text: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let places = try await OpenMeteoClient().searchPlaces(named: text)
            guard !Task.isCancelled else { return }
            results = places
            errorMessage = places.isEmpty ? "No matches for “\(text)”." : nil
        } catch {
            guard !Task.isCancelled else { return }
            // Say what happened: a silent empty list looks like "no such city".
            results = []
            errorMessage = "Search failed: \(error)"
        }
    }
}
