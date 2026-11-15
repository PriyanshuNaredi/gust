//
//  OpenMeteoClient.swift
//  BreezyUnits
//
//  Minimal transport for the ported request/response. Upstream uses OkHttp +
//  Retrofit + RxJava; here it is URLSession, and the only behaviour that matters
//  is carried over: a body-level error with HTTP 200 still counts as a failure.
//

import Foundation

public enum OpenMeteoError: Error, Equatable {
    /// The service answered, but said no (including HTTP 200 with `error: true`).
    case service(String)
    /// Transport-level failure, already described.
    case transport(String)
    /// Decoded fine, but produced nothing usable.
    case empty
}

public struct OpenMeteoClient: Sendable {
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetch(
        latitude: Double,
        longitude: Double,
        baseURL: String = OpenMeteoRequest.baseURL
    ) async throws -> OpenMeteoWeatherResult {
        let url = OpenMeteoRequest.url(latitude: latitude, longitude: longitude, baseURL: baseURL)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenMeteoError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            // Open-Meteo documents its 4xx bodies the same way as its 200 error
            // bodies, so try to decode the reason before giving up.
            if let result = try? JSONDecoder().decode(OpenMeteoWeatherResult.self, from: data),
               let reason = result.reason {
                throw OpenMeteoError.service(reason)
            }
            throw OpenMeteoError.transport("HTTP \(http.statusCode)")
        }

        let result: OpenMeteoWeatherResult
        do {
            result = try JSONDecoder().decode(OpenMeteoWeatherResult.self, from: data)
        } catch {
            throw OpenMeteoError.transport("decode failed: \(error.localizedDescription)")
        }

        if let reason = OpenMeteoMapping.failureReason(in: result) {
            throw OpenMeteoError.service(reason)
        }
        return result
    }

    /// The air-quality endpoint. Separate call, separate host, and its failures must
    /// not take the forecast down with them — callers decide that.
    public func fetchAirQuality(
        latitude: Double,
        longitude: Double,
        baseURL: String = OpenMeteoAirQualityRequest.baseURL
    ) async throws -> OpenMeteoAirQualityResult {
        let url = OpenMeteoAirQualityRequest.url(latitude: latitude, longitude: longitude, baseURL: baseURL)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OpenMeteoError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let result = try? JSONDecoder().decode(OpenMeteoAirQualityResult.self, from: data),
               let reason = result.reason {
                throw OpenMeteoError.service(reason)
            }
            throw OpenMeteoError.transport("HTTP \(http.statusCode)")
        }

        let result: OpenMeteoAirQualityResult
        do {
            result = try JSONDecoder().decode(OpenMeteoAirQualityResult.self, from: data)
        } catch {
            throw OpenMeteoError.transport("decode failed: \(error.localizedDescription)")
        }
        if result.error == true {
            throw OpenMeteoError.service(result.reason ?? "Open-Meteo reported an error")
        }
        return result
    }

    public func fetchCurrent(
        latitude: Double,
        longitude: Double,
        baseURL: String = OpenMeteoRequest.baseURL
    ) async throws -> CurrentObservation {
        let result = try await fetch(latitude: latitude, longitude: longitude, baseURL: baseURL)
        guard let raw = result.current else { throw OpenMeteoError.empty }
        return OpenMeteoMapping.current(from: raw)
    }
}
