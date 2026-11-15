//
//  ContentView.swift
//  Gust
//
//  The app's root. Three tabs, matching what this port can actually do: the forecast,
//  the saved places, and settings. Upstream's fourth and fifth surfaces (widgets,
//  notifications) have no iOS port -- they are documented as out of scope rather than
//  faked with empty screens.
//

import BreezyUnits
import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        TabView {
            ForecastScreen()
                .environment(appState)
                .tabItem { Label("Weather", systemImage: "cloud.sun") }

            NavigationStack { LocationsScreen() }
                .environment(appState)
                .tabItem { Label("Locations", systemImage: "list.bullet") }

            SettingsScreen()
                .environment(appState)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        // Applied once at the root so every screen follows the setting, including the
        // sheets and detail pages that are presented over it.
        .preferredColorScheme(appState.theme.colorScheme)
    }
}

#Preview {
    ContentView()
}
