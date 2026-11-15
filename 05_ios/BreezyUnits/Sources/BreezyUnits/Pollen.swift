//
//  Pollen.swift
//  BreezyUnits
//
//  Ported from `sources/openmeteo/OpenMeteoService.kt` (`getPollen`) and its
//  `COPERNICUS_POLLEN_BBOX` gate.
//
//  The gate matters: the pollen variables only exist over CAMS's European domain.
//  Requesting them outside it returns nothing, which reads as "no pollen today"
//  rather than "not covered" — so the app asks only inside the box, and this file
//  knows where the box is.
//

import Foundation

public enum PollenType: String, CaseIterable, Sendable {
    case alder, birch, grass, mugwort, olive, ragweed
}

/// Grains per cubic metre, which is what the service sends.
public struct Pollen: Hashable, Sendable {
    public let alder: Double?
    public let birch: Double?
    public let grass: Double?
    public let mugwort: Double?
    public let olive: Double?
    public let ragweed: Double?

    public init(
        alder: Double? = nil,
        birch: Double? = nil,
        grass: Double? = nil,
        mugwort: Double? = nil,
        olive: Double? = nil,
        ragweed: Double? = nil
    ) {
        self.alder = alder
        self.birch = birch
        self.grass = grass
        self.mugwort = mugwort
        self.olive = olive
        self.ragweed = ragweed
    }

    public func value(of type: PollenType) -> Double? {
        switch type {
        case .alder: return alder
        case .birch: return birch
        case .grass: return grass
        case .mugwort: return mugwort
        case .olive: return olive
        case .ragweed: return ragweed
        }
    }

    /// The pollen with the highest count right now — what the card shows.
    public var dominant: (type: PollenType, value: Double)? {
        PollenType.allCases
            .compactMap { type in value(of: type).map { (type, $0) } }
            .max { $0.1 < $1.1 }
    }

    /// False when nothing is measurable, including an all-zero hour: "0.0 grains"
    /// and "no data at all" are different claims and the card says which.
    public var hasPollen: Bool {
        PollenType.allCases.contains { (value(of: $0) ?? 0) > 0 }
    }
}

public enum PollenCoverage {
    /// CAMS European domain: 25° W to 45° E, 30° N to 72° N.
    public static let westBoundary: Double = -25
    public static let eastBoundary: Double = 45
    public static let southBoundary: Double = 30
    public static let northBoundary: Double = 72

    public static func covers(latitude: Double, longitude: Double) -> Bool {
        latitude >= southBoundary && latitude <= northBoundary
            && longitude >= westBoundary && longitude <= eastBoundary
    }
}

public extension OpenMeteoMapping {
    static func pollenByDate(from raw: OpenMeteoAirQualityHourly?) -> [Date: Pollen] {
        guard let raw else { return [:] }
        var result: [Date: Pollen] = [:]
        for index in raw.time.indices {
            func value(_ array: [Double?]?) -> Double? {
                guard let array, index < array.count else { return nil }
                return array[index]
            }
            result[date(fromUnixSeconds: raw.time[index])] = Pollen(
                alder: value(raw.alderPollen),
                birch: value(raw.birchPollen),
                grass: value(raw.grassPollen),
                mugwort: value(raw.mugwortPollen),
                olive: value(raw.olivePollen),
                ragweed: value(raw.ragweedPollen)
            )
        }
        return result
    }
}
