//
//  OpenMeteoMapping.swift
//  BreezyUnits
//
//  Open-Meteo wire values → domain types. The unit of each field comes from the
//  response's own `*_units` block, which this port checks against the fixture
//  rather than assuming: `windspeed_unit=ms` (m/s), `precipitation` (mm),
//  `snowfall` (cm — the one field that is not mm), `pressure_msl` (hPa),
//  `visibility` (m), `relative_humidity`/`cloud_cover` (%).
//

import Foundation

public enum OpenMeteoMapping {
    /// Unix seconds → Date. Upstream asks for `timeformat=unixtime`, so the whole
    /// payload is epoch seconds and no date parsing is involved.
    static func date(fromUnixSeconds seconds: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    public static func current(from raw: OpenMeteoCurrent) -> CurrentObservation {
        CurrentObservation(
            date: date(fromUnixSeconds: raw.time),
            weatherCode: raw.weatherCode,
            temperature: raw.temperature.map { $0.celsius },
            apparentTemperature: raw.apparentTemperature.map { $0.celsius },
            wind: Wind(
                speed: raw.windSpeed.map { $0.metersPerSecond },
                direction: raw.windDirection,
                gusts: raw.windGusts.map { $0.metersPerSecond }
            ),
            uvIndex: raw.uvIndex,
            relativeHumidity: raw.relativeHumidity.map { Double($0).percent },
            dewPoint: raw.dewPoint.map { $0.celsius },
            pressure: raw.pressureMsl.map { $0.hectopascals },
            cloudCover: raw.cloudCover.map { Double($0).percent },
            visibility: raw.visibility.map { $0.meters }
        )
    }

    /// A decoded payload is not necessarily a usable one: Open-Meteo answers some
    /// failures with HTTP 200 and `error: true`, so callers must check this.
    public static func failureReason(in result: OpenMeteoWeatherResult) -> String? {
        if result.error == true { return result.reason ?? "Open-Meteo reported an error" }
        if result.current == nil && result.daily == nil && result.hourly == nil {
            return "Open-Meteo returned no weather data"
        }
        return nil
    }
}
