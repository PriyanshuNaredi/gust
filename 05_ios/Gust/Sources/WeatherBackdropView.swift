//
//  WeatherBackdropView.swift
//  Gust
//
//  The main screen's background. Upstream draws a three-stop gradient asset chosen by
//  (weather kind, daylight, theme) and animates a geometric scene over it; both are
//  ported in `BreezyUnits.WeatherScene` and drawn by `WeatherSceneView`.
//
//  This wrapper exists for the two things that are the *screen's* business rather than
//  the scene's: fading the background out as the content scrolls over it, and exposing
//  one stable accessibility identifier to the UI tests.
//

import BreezyUnits
import SwiftUI

struct WeatherBackdropView: View {
    let kind: WeatherKind
    let daylight: Bool
    var animated: Bool = true

    var body: some View {
        WeatherSceneView(kind: kind, daylight: daylight, animated: animated)
            .accessibilityIdentifier("backdrop")
    }
}
