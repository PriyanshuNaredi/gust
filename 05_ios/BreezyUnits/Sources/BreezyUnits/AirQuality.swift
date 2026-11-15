//
//  AirQuality.swift
//  BreezyUnits
//
//  Ported from `domain/weather/model/AirQuality.kt` (LGPL-3.0).
//
//  The headline index is the **maximum over O3, NO2, PM10 and PM25 only** — CO and
//  SO2 are shown but never drive the number. That is upstream's choice, not an
//  oversight, and it changes the displayed value on exactly the days a port would
//  be compared against.
//

import Foundation

public struct AirQuality: Hashable, Sendable {
    public let pm25: PollutantConcentration?
    public let pm10: PollutantConcentration?
    public let o3: PollutantConcentration?
    public let no2: PollutantConcentration?
    public let so2: PollutantConcentration?
    public let co: PollutantConcentration?

    public init(
        pm25: PollutantConcentration? = nil,
        pm10: PollutantConcentration? = nil,
        o3: PollutantConcentration? = nil,
        no2: PollutantConcentration? = nil,
        so2: PollutantConcentration? = nil,
        co: PollutantConcentration? = nil
    ) {
        self.pm25 = pm25
        self.pm10 = pm10
        self.o3 = o3
        self.no2 = no2
        self.so2 = so2
        self.co = co
    }

    public func concentration(of pollutant: Pollutant) -> PollutantConcentration? {
        switch pollutant {
        case .pm25: return pm25
        case .pm10: return pm10
        case .o3: return o3
        case .no2: return no2
        case .so2: return so2
        case .co: return co
        }
    }

    /// nil when no pollutant in the four has a value.
    public var index: Int? {
        index(for: nil)
    }

    /// `nil` pollutant means "overall", mirroring upstream's default argument.
    public func index(for pollutant: Pollutant?) -> Int? {
        if let pollutant {
            return PollutantIndex.index(of: pollutant, concentration: concentration(of: pollutant)?.microgramsPerCubicMeter)
        }
        let values: [Int?] = [
            index(for: .o3), index(for: .no2), index(for: .pm10), index(for: .pm25)
        ]
        let present = values.compactMap { $0 }
        return present.isEmpty ? nil : present.max()
    }

    public var indexLevel: Int? {
        PollutantIndex.level(forIndex: index)
    }
}
