//
//  TemperatureComputing.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../computing/TemperatureComputing.kt` (LGPL-3.0).
//  Only the functions whose upstream tests give numeric expectations are ported
//  so far: humidex. `computeApparentTemperature` and `computeWindChillTemperature`
//  need `Ratio` and `Speed`, which land with the next slice.
//

import Foundation

/// Humidex, as upstream defines it. Requires temperature ≥ 15 °C.
public func computeHumidex(temperature: Temperature?, dewPoint: Temperature?) -> Temperature? {
    guard let temperature, let dewPoint, temperature >= 15.celsius else { return nil }
    let celsius = temperature.inCelsius
    let dp = dewPoint.inCelsius
    let vapourPressure = exp(5417.7530 * (1 / 273.15 - 1 / (273.15 + dp))) * 6.11 - 10
    return (celsius + 0.5555 * vapourPressure).celsius
}
