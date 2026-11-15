//
//  TemperatureComputing.swift
//  BreezyUnits
//
//  Ported from `weather-unit/.../computing/TemperatureComputing.kt` (LGPL-3.0).
//  The formulas are upstream's, including the guard conditions and their order:
//  a wrong guard here shows up as a plausible-looking but wrong "feels like".
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

/// Apparent temperature (Australian Bureau of Meteorology formula).
/// Returns nil unless all three inputs exist — upstream does the same, so a
/// missing wind speed hides the whole card rather than guessing.
public func computeApparentTemperature(
    temperature: Temperature?,
    relativeHumidity: Ratio?,
    windSpeed: Speed?
) -> Temperature? {
    guard let temperature, let relativeHumidity, let windSpeed else { return nil }
    let celsius = temperature.inCelsius
    let vapourPressure = relativeHumidity.inFraction * 6.105 * exp(17.27 * celsius / (237.7 + celsius))
    return (celsius + 0.33 * vapourPressure - 0.7 * windSpeed.inMetersPerSecond - 4.0).celsius
}

/// Wind chill (Environment Canada / NWS formula with the low-wind branch).
///
/// Three guards, in this order, exactly as upstream:
/// 1. above 10 °C there is no wind chill → nil
/// 2. at or above 5 km/h, the full formula
/// 3. below that, only when it is at or below 0 °C, the simplified formula
/// otherwise nil.
public func computeWindChillTemperature(temperature: Temperature?, windSpeed: Speed?) -> Temperature? {
    guard let temperature, let windSpeed, temperature <= 10.celsius else { return nil }
    let celsius = temperature.inCelsius
    let kmh = windSpeed.inKilometersPerHour
    if windSpeed >= 5.kilometersPerHour {
        let windFactor = pow(kmh, 0.16)
        return (13.12 + 0.6215 * celsius - 11.37 * windFactor + 0.3965 * celsius * windFactor).celsius
    } else if temperature <= 0.celsius {
        return (celsius + ((-1.59 + 0.1345 * celsius) / 5.0) * kmh).celsius
    } else {
        return nil
    }
}

/// Probability that it rains at all: upstream takes the maximum over the
/// mutually exclusive precipitation types rather than combining them.
public func computeTotalProbabilityOfPrecipitation(
    thunderstorm: Ratio?,
    rain: Ratio?,
    snow: Ratio?,
    ice: Ratio?
) -> Ratio? {
    if thunderstorm == nil && rain == nil && snow == nil && ice == nil { return nil }
    let maxPermille = max(
        max(thunderstorm?.referenceValue ?? 0, rain?.referenceValue ?? 0),
        max(snow?.referenceValue ?? 0, ice?.referenceValue ?? 0)
    )
    return Ratio(referenceValue: maxPermille)
}
