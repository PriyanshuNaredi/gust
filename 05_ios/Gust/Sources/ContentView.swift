//
//  ContentView.swift
//  Gust
//
//  The app's root. One navigation stack, no tab bar: upstream's main screen is the
//  forecast, with the place list behind the top-left button and settings behind the
//  overflow menu. A bottom tab bar is the most iOS-looking thing a port can add, and
//  the original has never had one.
//

import BreezyUnits
import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        ForecastScreen()
            .environment(appState)
        // Applied once at the root so every screen follows the setting, including the
        // sheets and detail pages that are presented over it.
        .preferredColorScheme(appState.theme.colorScheme)
    }
}

#Preview {
    ContentView()
}
