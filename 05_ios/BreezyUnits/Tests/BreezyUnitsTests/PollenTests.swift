//
//  PollenTests.swift
//  BreezyUnits
//
//  The pollen gate and the "no data vs no pollen" distinction, which is the whole
//  reason this file exists.
//

import XCTest
@testable import BreezyUnits

final class PollenTests: XCTestCase {
    func testCoverageBoxMatchesTheCamsDomain() {
        // Europe inside, everywhere else outside.
        XCTAssertTrue(PollenCoverage.covers(latitude: 52.52, longitude: 13.41))   // Berlin
        XCTAssertTrue(PollenCoverage.covers(latitude: 30.0, longitude: -25.0))    // SW corner
        XCTAssertTrue(PollenCoverage.covers(latitude: 72.0, longitude: 45.0))     // NE corner
        XCTAssertFalse(PollenCoverage.covers(latitude: 40.7, longitude: -74.0))   // New York
        XCTAssertFalse(PollenCoverage.covers(latitude: 35.7, longitude: 139.7))   // Tokyo
        XCTAssertFalse(PollenCoverage.covers(latitude: -33.9, longitude: 18.4))   // Cape Town
    }

    func testDominantReportsTheHighestCount() {
        let pollen = Pollen(alder: 12, birch: 300, grass: 42, ragweed: nil)
        let dominant = pollen.dominant
        XCTAssertEqual(dominant?.type, .birch)
        XCTAssertEqual(dominant?.value ?? 0, 300, accuracy: 0.001)
    }

    func testAllZeroHourIsNotTheSameAsMissingData() {
        let zeroes = Pollen(alder: 0, birch: 0, grass: 0)
        XCTAssertFalse(zeroes.hasPollen, "an all-zero hour reports no pollen")
        XCTAssertNotNil(zeroes.dominant, "but the value still exists, unlike a gap")

        let empty = Pollen()
        XCTAssertFalse(empty.hasPollen)
        XCTAssertNil(empty.dominant)
    }

    func testMappingKeepsNullsAsGaps() {
        // A missing array must not turn into zeros: that would claim clean air.
        let json = #"{"hourly": {"time": [1794708900], "birch_pollen": [null]}}"#
        let result = try? JSONDecoder().decode(OpenMeteoAirQualityResult.self, from: Data(json.utf8))
        let mapped = OpenMeteoMapping.pollenByDate(from: result?.hourly)
        XCTAssertEqual(mapped.count, 1)
        XCTAssertNil(mapped.values.first?.birch)
        XCTAssertFalse(mapped.values.first?.hasPollen ?? true)
    }

    func testRequestAddsPollenOnlyWhenAsked() throws {
        let without = OpenMeteoAirQualityRequest.url(latitude: 52.52, longitude: 13.41)
        let with = OpenMeteoAirQualityRequest.url(latitude: 52.52, longitude: 13.41, includePollen: true)

        func hourly(_ url: URL) throws -> String {
            let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
            return try XCTUnwrap(components.queryItems?.first { $0.name == "hourly" }?.value)
        }
        let plain = try hourly(without)
        let pollen = try hourly(with)
        XCTAssertFalse(plain.contains("pollen"))
        XCTAssertEqual(pollen.split(separator: ",").count, plain.split(separator: ",").count + 6)
        XCTAssertTrue(pollen.hasSuffix("ragweed_pollen"), "upstream's pollen order ends with ragweed")
    }
}
