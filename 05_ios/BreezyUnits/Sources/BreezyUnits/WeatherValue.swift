//
//  WeatherValue.swift
//  BreezyUnits
//
//  Ported from Breezy Weather `weather-unit` (LGPL-3.0), tag v6.2.2.
//
//  The upstream design stores every quantity as an Int64 in one fixed *reference
//  unit* per dimension (decidegrees Celsius, micrometres, permille, ...) and
//  converts to/from display units through closures on the unit enum. That design
//  is kept exactly: it makes equality and comparison exact, avoids float drift in
//  stored data, and lets the display unit change without touching model code.
//

import Foundation

/// A unit within one dimension: it knows how to convert to and from the
/// dimension's reference unit.
public protocol WeatherUnit: CaseIterable, Sendable {
    /// Converts a value expressed in the reference unit into this unit.
    func fromReference(_ value: Double) -> Double
    /// Converts a value expressed in this unit into the reference unit.
    func toReference(_ value: Double) -> Double
    /// Symbol for display, e.g. "°C". Upstream resolves this through Android
    /// resources; here it is a literal per unit.
    var symbol: String { get }
}

/// A stored quantity: an Int64 in the reference unit.
public protocol WeatherValue: Comparable, Hashable, Sendable {
    associatedtype Unit: WeatherUnit
    init(referenceValue: Int64)
    var referenceValue: Int64 { get }
    static var referenceUnit: Unit { get }
}

public extension WeatherValue {
    /// Creates a value from a number expressed in the given unit.
    init(_ value: Double, unit: Unit) {
        self.init(referenceValue: Int64(unit.toReference(value).rounded()))
    }

    /// Creates a value from a whole number expressed in the given unit.
    init(_ value: Int64, unit: Unit) {
        self.init(referenceValue: Int64(unit.toReference(Double(value)).rounded()))
    }

    /// This value expressed in the given display unit.
    func converted(to unit: Unit) -> Double {
        unit.fromReference(Double(referenceValue))
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.referenceValue < rhs.referenceValue }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.referenceValue == rhs.referenceValue }
}

/// Linear conversion helper for units that are a simple factor of the reference
/// unit (`toReference = value * factor`). Kept as a protocol so each dimension
/// can still express non-linear units (temperature) directly.
public protocol FactorConvertibleUnit: WeatherUnit {
    static var factorToReference: Double { get }
}

public extension FactorConvertibleUnit {
    func fromReference(_ value: Double) -> Double { value / Self.factorToReference }
    func toReference(_ value: Double) -> Double { value * Self.factorToReference }
}
