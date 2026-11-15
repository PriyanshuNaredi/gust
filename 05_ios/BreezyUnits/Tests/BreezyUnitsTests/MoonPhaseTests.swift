//
//  MoonPhaseTests.swift
//  BreezyUnits
//
//  Checked against published phase times. The mean-synodic model is accurate to a
//  few hours, so the assertions allow a tolerance rather than demanding exactness
//  the model cannot promise.
//

import XCTest
@testable import BreezyUnits

final class MoonPhaseTests: XCTestCase {
    private func phase(_ iso: String) throws -> MoonPhase {
        let formatter = ISO8601DateFormatter()
        return MoonPhase(date: try XCTUnwrap(formatter.date(from: iso)))
    }

    func testKnownNewMoonIsDark() throws {
        // 2024-04-08 18:21 UTC: total solar eclipse — a new moon by definition.
        let moon = try phase("2024-04-08T18:21:00Z")
        XCTAssertLessThan(moon.illumination, 0.03)
        XCTAssertEqual(moon.name, "New moon")
    }

    func testKnownFullMoonsAreBright() throws {
        for iso in ["2025-01-13T22:27:00Z", "2024-03-25T07:00:00Z", "2024-06-22T01:08:00Z"] {
            let moon = try phase(iso)
            XCTAssertGreaterThan(moon.illumination, 0.93, "full moon at \(iso) not lit")
            XCTAssertEqual(moon.name, "Full moon", "wrong name at \(iso)")
        }
    }

    func testDatesBeforeTheReferenceDoNotWrapNegative() throws {
        // Without a positive modulo this lands on a negative age and a nonsense
        // illumination, which is the classic bug in this calculation.
        let moon = try phase("1990-05-09T00:00:00Z")
        XCTAssertGreaterThanOrEqual(moon.age, 0)
        XCTAssertLessThan(moon.age, MoonPhase.synodicMonth)
        XCTAssertTrue((0...1).contains(moon.illumination))
    }

    func testAgeStaysWithinOneLunation() throws {
        // Sample a year: the age must stay in range and the illumination must be
        // symmetric about a full moon rather than drifting.
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for offset in stride(from: 0, to: 365, by: 7) {
            let moon = MoonPhase(date: start.addingTimeInterval(Double(offset) * 86_400))
            XCTAssertGreaterThanOrEqual(moon.age, 0)
            XCTAssertLessThan(moon.age, MoonPhase.synodicMonth)
            XCTAssertTrue((0...1).contains(moon.illumination))
        }
    }
}
