//
//  Geocoding.swift
//  BreezyUnits
//
//  Place search. Upstream uses Android's Geocoder or a bundled city list; this port
//  uses Open-Meteo's geocoding service, which is the same family as the weather data
//  and needs no key.
//
//  Ported behaviour worth keeping: results carry their own IANA time zone, so a
//  search result is enough to render correct local times *before* any weather
//  arrives.
//

import Foundation

public struct Place: Codable, Hashable, Identifiable, Sendable {
    /// Open-Meteo's geonames id. Stable across searches, so it identifies a saved place.
    public let id: Int
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let country: String?
    public let admin1: String?
    /// IANA zone name, e.g. "Europe/Berlin".
    public let timezone: String?
    public let population: Int?

    public init(
        id: Int,
        name: String,
        latitude: Double,
        longitude: Double,
        country: String? = nil,
        admin1: String? = nil,
        timezone: String? = nil,
        population: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.country = country
        self.admin1 = admin1
        self.timezone = timezone
        self.population = population
    }

    /// "Berlin, State of Berlin, Germany" without repeating the name.
    public var subtitle: String {
        let parts = [admin1, country].compactMap { $0 }.filter { !$0.isEmpty && $0 != name }
        return parts.joined(separator: ", ")
    }

    public var resolvedTimeZone: TimeZone {
        timezone.flatMap(TimeZone.init(identifier:)) ?? .current
    }
}

public struct GeocodingResult: Decodable {
    public let results: [Place]?
    public let generationtimeMs: Double?

    enum CodingKeys: String, CodingKey {
        case results
        case generationtimeMs = "generationtime_ms"
    }
}

public enum GeocodingRequest {
    public static let baseURL = "https://geocoding-api.open-meteo.com/v1/search"

    public static func url(name: String, count: Int = 10, language: String = "en") -> URL? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty query is a request for the whole world; refuse it rather than
        // sending something the service will reject anyway.
        guard trimmed.count >= 2 else { return nil }
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            .init(name: "name", value: trimmed),
            .init(name: "count", value: String(count)),
            .init(name: "language", value: language),
            .init(name: "format", value: "json")
        ]
        return components.url
    }
}

public extension OpenMeteoClient {
    func searchPlaces(named name: String, count: Int = 10) async throws -> [Place] {
        guard let url = GeocodingRequest.url(name: name, count: count) else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let data: Data
        do {
            (data, response: _) = try await session.data(for: request)
        } catch {
            throw OpenMeteoError.transport(error.localizedDescription)
        }
        do {
            return try JSONDecoder().decode(GeocodingResult.self, from: data).results ?? []
        } catch {
            throw OpenMeteoError.transport("decode failed: \(error.localizedDescription)")
        }
    }
}
