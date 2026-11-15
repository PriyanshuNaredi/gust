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
            weatherCode: OpenMeteoMapping.weatherCode(fromWMO: raw.weatherCode),
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

// MARK: - Forecast mapping

public extension OpenMeteoMapping {
    /// Hourly arrays are positional; a missing array simply yields nil for that
    /// field for every hour, which is what upstream does too.
    static func hourly(from raw: OpenMeteoHourly) -> [HourlyForecast] {
        raw.time.indices.map { index in
            func value<T>(_ array: [T?]?) -> T? {
                guard let array, index < array.count else { return nil }
                return array[index]
            }
            return HourlyForecast(
                date: date(fromUnixSeconds: raw.time[index]),
                weatherCode: OpenMeteoMapping.weatherCode(fromWMO: value(raw.weatherCode)),
                temperature: value(raw.temperature).map { $0.celsius },
                apparentTemperature: value(raw.apparentTemperature).map { $0.celsius },
                precipitationProbability: value(raw.precipitationProbability).map { Double($0).percent },
                precipitation: value(raw.precipitation).map { $0.millimeters },
                // Upstream stores rain and showers as one "rain" total.
                rain: combined(value(raw.rain), value(raw.showers)),
                showers: value(raw.showers).map { $0.millimeters },
                // Centimetres on the wire for snowfall only.
                snow: value(raw.snowfall).map { $0.centimeters },
                wind: Wind(
                    speed: value(raw.windSpeed).map { $0.metersPerSecond },
                    direction: value(raw.windDirection).map(Double.init),
                    gusts: value(raw.windGusts).map { $0.metersPerSecond }
                ),
                uvIndex: value(raw.uvIndex),
                isDay: value(raw.isDay).map { $0 == 1 },
                relativeHumidity: value(raw.relativeHumidity).map { Double($0).percent },
                dewPoint: value(raw.dewPoint).map { $0.celsius },
                pressure: value(raw.pressureMsl).map { $0.hectopascals },
                cloudCover: value(raw.cloudCover).map { Double($0).percent },
                visibility: value(raw.visibility).map { $0.meters }
            )
        }
    }

    static func daily(from raw: OpenMeteoDaily, timeZone: TimeZone) -> [DailyForecast] {
        // Upstream iterates `0 until dailyResult.time.size - 1`: the last day of the
        // payload is deliberately dropped. Keeping it would show one more day than
        // the Android app does.
        raw.time.indices.dropLast().map { index in
            func value<T>(_ array: [T?]?) -> T? {
                guard let array, index < array.count else { return nil }
                return array[index]
            }
            return DailyForecast(
                date: dailyDate(fromUnixSeconds: raw.time[index], timeZone: timeZone),
                temperatureMax: value(raw.temperatureMax).map { $0.celsius },
                temperatureMin: value(raw.temperatureMin).map { $0.celsius },
                apparentTemperatureMax: value(raw.apparentTemperatureMax).map { $0.celsius },
                apparentTemperatureMin: value(raw.apparentTemperatureMin).map { $0.celsius },
                // Sunshine duration arrives in seconds already.
                sunshineDuration: value(raw.sunshineDuration),
                uvIndexMax: value(raw.uvIndexMax),
                relativeHumidityMean: value(raw.relativeHumidityMean).map { Double($0).percent },
                relativeHumidityMax: value(raw.relativeHumidityMax).map { Double($0).percent },
                relativeHumidityMin: value(raw.relativeHumidityMin).map { Double($0).percent },
                dewPointMean: value(raw.dewPointMean).map { $0.celsius },
                dewPointMax: value(raw.dewPointMax).map { $0.celsius },
                dewPointMin: value(raw.dewPointMin).map { $0.celsius },
                pressureMean: value(raw.pressureMslMean).map { $0.hectopascals },
                pressureMax: value(raw.pressureMslMax).map { $0.hectopascals },
                pressureMin: value(raw.pressureMslMin).map { $0.hectopascals },
                cloudCoverMean: value(raw.cloudCoverMean).map { Double($0).percent },
                cloudCoverMax: value(raw.cloudCoverMax).map { Double($0).percent },
                cloudCoverMin: value(raw.cloudCoverMin).map { Double($0).percent },
                visibilityMean: value(raw.visibilityMean).map { $0.meters },
                visibilityMax: value(raw.visibilityMax).map { $0.meters },
                visibilityMin: value(raw.visibilityMin).map { $0.meters }
            )
        }
    }

    /// One entry per step, nulls kept: the time series is the product, so a gap
    /// must not shorten it.
    /// Upstream's DST-safe day anchor: take the timestamp, add an hour, then zero
    /// the hour — so the date is local midnight even across a DST boundary, where a
    /// naive `startOfDay` can land on the wrong day.
    static func dailyDate(fromUnixSeconds seconds: Int64, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let shifted = calendar.date(byAdding: .hour, value: 1, to: date(fromUnixSeconds: seconds))
            ?? date(fromUnixSeconds: seconds)
        return calendar.startOfDay(for: shifted)
    }

    /// Sums two optional precipitation arrays; nil only when both are nil.
    static func combined(_ lhs: Double?, _ rhs: Double?) -> Precipitation? {
        switch (lhs, rhs) {
        case (nil, nil): return nil
        default: return ((lhs ?? 0) + (rhs ?? 0)).millimeters
        }
    }

    static func minutely(from raw: OpenMeteoMinutely?) -> [MinutelyForecast] {
        guard let raw else { return [] }
        let values = raw.precipitation ?? []
        return raw.time.indices.map { index in
            let value = index < values.count ? values[index] : nil
            return MinutelyForecast(
                date: date(fromUnixSeconds: raw.time[index]),
                precipitation: value.map { $0.millimeters }
            )
        }
    }

    /// Whole payload → `Weather`. `refreshTime` is when we asked, not when the
    /// model compiled, which is what upstream records too.
    static func weather(
        from result: OpenMeteoWeatherResult,
        timeZone: TimeZone? = nil,
        refreshedAt: Date = Date()
    ) -> Weather {
        // Prefer the service's own IANA name; fall back to its numeric offset.
        let zone = timeZone
            ?? result.timezone.flatMap(TimeZone.init(identifier:))
            ?? TimeZone(secondsFromGMT: result.utcOffsetSeconds ?? 0)
            ?? .gmt
        return Weather(
            current: result.current.map { current(from: $0) },
            hourlyForecast: result.hourly.map { hourly(from: $0) } ?? [],
            dailyForecast: result.daily.map { daily(from: $0, timeZone: zone) } ?? [],
            minutelyForecast: minutely(from: result.minutelyFifteen),
            refreshTime: refreshedAt
        )
    }
}
