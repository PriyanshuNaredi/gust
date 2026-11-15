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

    /// Set by the view from AppState. Changing it reloads.
    var place: Place = AppState.defaultPlace
    private var loadedPlaceID: Int?

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
        guard !hasLoaded || loadedPlaceID != place.id else { return }
        await reload()
    }

    func reload() async {
        hasLoaded = true
        loadedPlaceID = place.id
        state = .loading
        do {
            let client = OpenMeteoClient()
            async let weatherResult = client.fetch(
                latitude: place.latitude, longitude: place.longitude, baseURL: baseURL
            )
            // Air quality is a separate endpoint: its failure must not take the
            // forecast down, so it is best-effort and defaults to absent.
            // Pollen variables exist only over the CAMS European domain; asking
            // outside it returns nothing and would read as "no pollen today".
            let wantsPollen = PollenCoverage.covers(latitude: place.latitude, longitude: place.longitude)
            async let airResult: OpenMeteoAirQualityResult? = {
                do {
                    return try await client.fetchAirQuality(
                        latitude: place.latitude, longitude: place.longitude, includePollen: wantsPollen
                    )
                }
                catch { return nil }
            }()

            let result = try await weatherResult
            let payload = try? await airResult
            let air = OpenMeteoMapping.airQualityByDate(from: payload?.hourly)
            let pollen = wantsPollen ? OpenMeteoMapping.pollenByDate(from: payload?.hourly) : [:]
            var weather = OpenMeteoMapping.weather(from: result)
            // A "loaded" state with nothing in it would show an empty card stack and
            // look like a rendering bug, so treat it as a failure instead.
            guard weather.current != nil || !weather.dailyForecast.isEmpty else {
                state = .failed("no usable weather in the response")
                return
            }
            weather = Weather(
                current: weather.current,
                hourlyForecast: weather.hourlyForecast,
                dailyForecast: weather.dailyForecast,
                minutelyForecast: weather.minutelyForecast,
                airQuality: air,
                pollen: pollen,
                timeZone: weather.timeZone,
                refreshTime: weather.refreshTime
            )
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
