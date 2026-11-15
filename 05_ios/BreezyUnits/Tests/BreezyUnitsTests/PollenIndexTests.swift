//
//  PollenIndexTests.swift
//  BreezyUnits
//
//  Grass 30 grains is already "Moderate" while birch 30 is still "Very low": the
//  per-type breakpoints are the point of this file.
//

import XCTest
@testable import BreezyUnits

final class PollenIndexTests: XCTestCase {
    func testGrassBreakpointsComeFromAtmoFrance() {
        // thresholds 0, 3, 30, 50, 250 -> index bands 0, 25, 50, 75, 100
        XCTAssertEqual(PollenIndexCalculator.index(for: .grass, concentration: 0), 0)
        XCTAssertEqual(PollenIndexCalculator.index(for: .grass, concentration: 3), 25)
        XCTAssertEqual(PollenIndexCalculator.index(for: .grass, concentration: 30), 50)
        XCTAssertEqual(PollenIndexCalculator.index(for: .grass, concentration: 50), 75)
        XCTAssertEqual(PollenIndexCalculator.index(for: .grass, concentration: 250), 100)
        // Interpolated, not snapped: halfway between 3 and 30 is halfway between
        // 25 and 50, within rounding.
        let midway = PollenIndexCalculator.index(for: .grass, concentration: 16.5)
        XCTAssertEqual(midway, 38)
    }

    func testTheSameConcentrationMeansDifferentThingsPerType() {
        XCTAssertEqual(PollenIndexCalculator.name(for: PollenIndexCalculator.index(for: .grass, concentration: 30)), "Moderate")
        // Birch needs 60 to reach "moderate"; at 30 it lands at index 35, one band down.
        XCTAssertEqual(PollenIndexCalculator.index(for: .birch, concentration: 30), 35)
        XCTAssertEqual(PollenIndexCalculator.name(for: 35), "Low")
    }

    func testAboveTheLastBreakpointItKeepsGrowing() {
        // Linear continuation: 500 grass is 200 index, not a clamped 100. A clamp
        // would make twice the pollen look identical.
        XCTAssertEqual(PollenIndexCalculator.index(for: .grass, concentration: 500), 200)
        XCTAssertGreaterThan(
            PollenIndexCalculator.index(for: .grass, concentration: 1000) ?? 0,
            PollenIndexCalculator.index(for: .grass, concentration: 500) ?? 0
        )
    }

    func testMissingConcentrationHasNoIndex() {
        XCTAssertNil(PollenIndexCalculator.index(for: .grass, concentration: nil))
        XCTAssertNil(PollenIndexCalculator.name(for: nil))
        XCTAssertNil(PollenIndexCalculator.level(for: nil))
    }

    func testZeroIsNoneWithItsOwnColour() {
        XCTAssertEqual(PollenIndexCalculator.name(for: 0), "None")
        XCTAssertEqual(PollenIndexCalculator.level(for: 0), .veryLow)
        XCTAssertEqual(PollenIndexCalculator.color(for: 0), RGBColor(hex: 0xBFBFBF))
        XCTAssertTrue(PollenIndexCalculator.level(for: 200) == .veryHigh, "the level saturates even when the index does not")
    }

    func testWorstTypePicksTheHighestIndexNotTheHighestCount() {
        // The same 20 grains is index 30 for birch and 41 for grass, because the
        // types have different breakpoints. The card must show the worse one, not
        // the bigger number.
        let pollen = Pollen(alder: nil, birch: 20, grass: 20)
        XCTAssertEqual(pollen.index(of: .birch), 30)
        XCTAssertEqual(pollen.index(of: .grass), 41)
        XCTAssertEqual(pollen.worstType?.type, .grass)

        let grassier = Pollen(birch: 20, grass: 40)
        XCTAssertEqual(grassier.worstType?.type, .grass)
    }

    func testColoursMatchUpstreamPalette() {
        XCTAssertEqual(PollenLevel.veryLow.color, RGBColor(hex: 0x08C286))
        XCTAssertEqual(PollenLevel.moderate.color, RGBColor(hex: 0xFFD741))
        XCTAssertEqual(PollenLevel.veryHigh.color, RGBColor(hex: 0xFF6B40))
    }
}
