//
//  ForecastStore.swift
//  Gust
//
//  Loads one location's weather through the ported Open-Meteo client. Deliberately
//  small: no cache, no refresh timer, no source selection — those are later slices.
//  The state enum exists so the screen cannot render "empty but looks loaded".
//

import BreezyUnits
import Foundation
import Observation

@MainActor
@Observable
final class ForecastStore {
    enum State {
        case loading
        case loaded(Weather)
        case failed(String)
    }

    private(set) var state: State = .loading

    /// Berlin, so the first card stack reproduces the fixture the tests use.
    let latitude: Double = 52.52
    let longitude: Double = 13.41
    let placeName: String = "Berlin"

    private var hasLoaded = false

    /// Test hook: UI tests need to force the failure branch without breaking the
    /// network. Absent in normal runs, so production behaviour is unaffected.
    private var baseURL: String {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-gustBaseURLOverride"), index + 1 < args.count {
            return args[index + 1]
        }
        return OpenMeteoRequest.baseURL
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        hasLoaded = true
        state = .loading
        do {
            let result = try await OpenMeteoClient().fetch(
                latitude: latitude, longitude: longitude, baseURL: baseURL
            )
            let weather = OpenMeteoMapping.weather(from: result)
            // A "loaded" state with nothing in it would show an empty card stack and
            // look like a rendering bug, so treat it as a failure instead.
            guard weather.current != nil || !weather.dailyForecast.isEmpty else {
                state = .failed("no usable weather in the response")
                return
            }
            state = .loaded(weather)
        } catch let error as OpenMeteoError {
            switch error {
            case .service(let reason): state = .failed(reason)
            case .transport(let reason): state = .failed(reason)
            case .empty: state = .failed("the source returned no current conditions")
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
