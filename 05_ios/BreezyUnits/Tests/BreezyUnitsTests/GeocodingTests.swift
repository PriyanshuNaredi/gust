//
//  GeocodingTests.swift
//  BreezyUnits
//
//  Place search, against a recorded payload. The point of these tests is the parts
//  that are easy to get wrong and impossible to see: the query guard, the subtitle
//  that must not repeat the city name, and the zone a result carries.
//

import XCTest
@testable import BreezyUnits

final class GeocodingTests: XCTestCase {
    private func fixture() throws -> GeocodingResult {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Resources/geocoding-berlin", withExtension: "json")
        )
        return try JSONDecoder().decode(GeocodingResult.self, from: Data(contentsOf: url))
    }

    func testDecodesRealSearchResults() throws {
        let results = try XCTUnwrap(try fixture().results)
        XCTAssertGreaterThanOrEqual(results.count, 3)
        let berlin = try XCTUnwrap(results.first)
        XCTAssertEqual(berlin.name, "Berlin")
        XCTAssertEqual(berlin.country, "Germany")
        XCTAssertEqual(berlin.timezone, "Europe/Berlin")
        // Coordinates are the source's, so a plausible range is a real check.
        XCTAssertTrue((52...53).contains(berlin.latitude))
        XCTAssertTrue((13...14).contains(berlin.longitude))
        XCTAssertEqual(berlin.resolvedTimeZone.identifier, "Europe/Berlin")
    }

    func testSubtitleDoesNotRepeatTheName() throws {
        let berlin = try XCTUnwrap(try fixture().results?.first)
        XCTAssertEqual(berlin.subtitle, "State of Berlin, Germany")
        XCTAssertFalse(berlin.subtitle.contains("Berlin, Berlin"))
    }

    func testIdentifiersAreStableAndUnique() throws {
        let results = try XCTUnwrap(try fixture().results)
        let ids = Set(results.map(\.id))
        XCTAssertEqual(ids.count, results.count, "duplicate ids would break saved-place identity")
    }

    func testShortQueriesAreRefusedLocally() {
        // No network call for something the service would reject: an empty query
        // means "every place on Earth".
        XCTAssertNil(GeocodingRequest.url(name: ""))
        XCTAssertNil(GeocodingRequest.url(name: " b "))
        XCTAssertNotNil(GeocodingRequest.url(name: "Berlin"))
    }

    func testRequestShape() throws {
        let url = try XCTUnwrap(GeocodingRequest.url(name: "Berlin"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let byName = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components.host, "geocoding-api.open-meteo.com")
        XCTAssertEqual(components.path, "/v1/search")
        XCTAssertEqual(byName["name"], "Berlin")
        XCTAssertEqual(byName["format"], "json")
        XCTAssertEqual(byName["language"], "en")
    }
}
