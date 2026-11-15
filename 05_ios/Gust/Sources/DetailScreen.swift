//
//  DetailScreen.swift
//  Gust
//
//  Detail pages for the cards. Upstream draws these with hand-rolled Compose
//  canvases; this port uses SwiftUI `Canvas` for the same reason — a chart library
//  would impose axes, animations and gestures that do not match, and three of these
//  charts are not line charts at all.
//
//  Scope: hourly and daily forecasts, and one series per metric card. Air quality
//  shows four pollutant series because that is what the data has.
//

import BreezyUnits
import SwiftUI

struct DetailScreen: View {
    let kind: MainCardKind
    let weather: Weather
    let units: UnitPreferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                chart
                values
            }
            .padding(16)
        }
        .navigationTitle(kind.detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("detail.screen")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kind.detailTitle)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        switch kind {
        case .hourly: return "Next 48 hours · \(weather.timeZone.identifier)"
        case .daily: return "\(weather.dailyForecast.count) days · \(weather.timeZone.identifier)"
        case .airQuality: return "Hourly · source Open-Meteo (CAMS)"
        case .pollen: return "Hourly · CAMS European domain only"
        default: return "Hourly · source Open-Meteo"
        }
    }

    @ViewBuilder
    private var chart: some View {
        switch kind {
        case .hourly: HourlyChart(weather: weather, units: units)
        case .daily: DailyChart(weather: weather, units: units)
        case .airQuality: AirQualityChart(weather: weather)
        case .pollen: PollenChart(weather: weather)
        default: MetricChart(weather: weather, units: units, metric: kind)
        }
    }

    @ViewBuilder
    private var values: some View {
        switch kind {
        case .hourly: HourlyValueList(weather: weather, units: units)
        case .daily: DailyValueList(weather: weather, units: units)
        case .airQuality: AirQualityValueList(weather: weather)
        case .pollen: PollenValueList(weather: weather)
        default: MetricValueList(weather: weather, units: units, metric: kind)
        }
    }
}

extension MainCardKind {
    var detailTitle: String {
        switch self {
        case .header: return "Now"
        case .alert: return "Alerts"
        case .precipitationNowcast: return "Precipitation nowcast"
        case .daily: return "Daily forecast"
        case .hourly: return "Hourly forecast"
        case .precipitation: return "Precipitation"
        case .wind: return "Wind"
        case .airQuality: return "Air quality"
        case .pollen: return "Pollen"
        case .humidity: return "Humidity"
        case .uv: return "UV index"
        case .visibility: return "Visibility"
        case .pressure: return "Pressure"
        case .sun: return "Sun"
        case .moon: return "Moon"
        case .clock: return "Local time"
        case .footer: return "About"
        }
    }

    /// Only cards with something to say get a detail page; the rest stay inert.
    var hasDetail: Bool {
        switch self {
        case .header, .footer, .clock, .moon, .sun, .alert: return false
        default: return true
        }
    }
}

// MARK: - Hourly

struct HourlyChart: View {
    let weather: Weather
    let units: UnitPreferences

    private var hours: [HourlyForecast] {
        guard let reference = weather.current?.date else { return Array(weather.hourlyForecast.prefix(48)) }
        return Array(weather.hourlyForecast(from: reference).prefix(48))
    }

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                let temperatures = hours.compactMap { $0.temperature.map { units.temperature == .fahrenheit ? $0.inFahrenheit : $0.inCelsius } }
                guard temperatures.count > 1 else { return }
                let low = temperatures.min() ?? 0
                let high = temperatures.max() ?? 1
                let span = max(high - low, 0.1)

                // Reserved left gutter so the extreme labels never sit under the line
                // (a vision check of the first build caught exactly that).
                let gutter: CGFloat = 40
                var path = Path()
                for (index, value) in temperatures.enumerated() {
                    let x = gutter + (size.width - gutter) * CGFloat(index) / CGFloat(temperatures.count - 1)
                    let y = size.height - size.height * CGFloat((value - low) / span) * 0.86 - 6
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(.orange), lineWidth: 2)

                // No axes: label the extremes instead, which is what the card needs.
                context.draw(
                    Text(String(format: "%.0f°", high)).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: gutter / 2, y: 10)
                )
                context.draw(
                    Text(String(format: "%.0f°", low)).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: gutter / 2, y: size.height - 8)
                )
            }
            .frame(height: 140)

            Canvas { context, size in
                let values = hours.map { max($0.precipitationProbability?.inPercent ?? 0, 0) }
                guard !values.isEmpty else { return }
                let slot = size.width / CGFloat(values.count)
                for (index, probability) in values.enumerated() {
                    let height = size.height * CGFloat(probability / 100)
                    guard height > 0.5 else { continue }
                    let rect = CGRect(x: slot * CGFloat(index), y: size.height - height, width: max(slot - 1, 1), height: height)
                    context.fill(Path(rect), with: .color(.blue.opacity(0.55)))
                }
            }
            .frame(height: 44)
            Text("Temperature and precipitation probability")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Daily

struct DailyChart: View {
    let weather: Weather
    let units: UnitPreferences

    var body: some View {
        Canvas { context, size in
            let days = weather.dailyForecast
            guard !days.isEmpty else { return }
            let lows = days.compactMap { units.temperature == .fahrenheit ? $0.temperatureMin?.inFahrenheit : $0.temperatureMin?.inCelsius }
            let highs = days.compactMap { units.temperature == .fahrenheit ? $0.temperatureMax?.inFahrenheit : $0.temperatureMax?.inCelsius }
            guard let scaleLow = lows.min(), let scaleHigh = highs.max() else { return }
            let span = max(scaleHigh - scaleLow, 0.1)
            let rowHeight = size.height / CGFloat(days.count)

            for (index, day) in days.enumerated() {
                let low = (units.temperature == .fahrenheit ? day.temperatureMin?.inFahrenheit : day.temperatureMin?.inCelsius) ?? scaleLow
                let high = (units.temperature == .fahrenheit ? day.temperatureMax?.inFahrenheit : day.temperatureMax?.inCelsius) ?? scaleLow
                let y = rowHeight * CGFloat(index) + rowHeight / 2
                let x0 = size.width * CGFloat((low - scaleLow) / span)
                let x1 = size.width * CGFloat((high - scaleLow) / span)
                var line = Path()
                line.move(to: CGPoint(x: x0, y: y))
                line.addLine(to: CGPoint(x: x1, y: y))
                context.stroke(line, with: .color(.orange.opacity(0.75)), style: StrokeStyle(lineWidth: rowHeight * 0.35, lineCap: .round))
            }
        }
        .frame(height: CGFloat(max(weather.dailyForecast.count, 1)) * 22)
        .accessibilityIdentifier("detail.dailyChart")
    }
}

// MARK: - Metric

struct MetricChart: View {
    let weather: Weather
    let units: UnitPreferences
    let metric: MainCardKind

    private var series: [Double] {
        let reference = weather.current?.date ?? Date()
        let hours = Array(weather.hourlyForecast(from: reference).prefix(48))
        return hours.compactMap { hour in
            switch metric {
            case .wind: return hour.wind?.speed.map { units.speed == .milesPerHour ? $0.inMilesPerHour : ($0.inMetersPerSecond) }
            case .humidity: return hour.relativeHumidity?.inPercent
            case .uv: return hour.uvIndex
            case .visibility: return hour.visibility?.inKilometers
            case .pressure: return hour.pressure?.inHectopascals
            case .precipitation: return hour.precipitation?.inMillimeters
            default: return nil
            }
        }
    }

    var body: some View {
        Canvas { context, size in
            guard series.count > 1 else { return }
            let low = series.min() ?? 0
            let high = series.max() ?? 1
            // A flat series would divide by zero and draw nothing; pad the span.
            let span = max(high - low, max(abs(high) * 0.05, 0.1))
            let gutter: CGFloat = 40
            var path = Path()
            for (index, value) in series.enumerated() {
                let x = gutter + (size.width - gutter) * CGFloat(index) / CGFloat(series.count - 1)
                let y = size.height - size.height * CGFloat((value - low) / span) * 0.9
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(.accentColor), lineWidth: 2)
            context.draw(Text(String(format: "%.1f", high)).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: gutter / 2, y: 10))
            context.draw(Text(String(format: "%.1f", low)).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: gutter / 2, y: size.height - 8))
        }
        .frame(height: 150)
        .accessibilityIdentifier("detail.metricChart")
    }
}

// MARK: - Air quality

struct AirQualityChart: View {
    let weather: Weather

    var body: some View {
        Canvas { context, size in
            let ordered = weather.airQuality.sorted { $0.key < $1.key }
            guard ordered.count > 1 else { return }
            let pollutants: [(String, Color, (AirQuality) -> Double?)] = [
                ("PM2.5", .orange, { $0.pm25?.microgramsPerCubicMeter }),
                ("PM10", .brown, { $0.pm10?.microgramsPerCubicMeter }),
                ("O3", .blue, { $0.o3?.microgramsPerCubicMeter }),
                ("NO2", .purple, { $0.no2?.microgramsPerCubicMeter })
            ]
            // Peak across every pollutant and hour, so the four lines share one scale.
            let peak = max(
                ordered.flatMap { entry in pollutants.compactMap { $0.2(entry.value) } }.max() ?? 1,
                1
            )

            for (_, color, accessor) in pollutants {
                let values = ordered.compactMap { accessor($0.value) }
                guard values.count > 1 else { continue }
                var path = Path()
                for (index, value) in values.enumerated() {
                    let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                    let y = size.height - size.height * CGFloat(value / peak) * 0.92
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(color), lineWidth: 1.5)
            }
            context.draw(Text(String(format: "%.0f µg/m³", peak)).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: 44, y: 10))
        }
        .frame(height: 150)
        .accessibilityIdentifier("detail.airChart")

        legend
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach([("PM2.5", Color.orange), ("PM10", .brown), ("O3", .blue), ("NO2", .purple)], id: \.0) { name, color in
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(name).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}


// MARK: - Pollen

struct PollenChart: View {
    let weather: Weather

    var body: some View {
        let ordered = weather.pollen.sorted { $0.key < $1.key }
        if ordered.isEmpty {
            // Not a chart with no data: a statement that this place is outside the
            // covered area, which is a different fact.
            Text("Pollen data covers Europe only. This place is outside the CAMS domain.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("detail.pollenNoCoverage")
        } else {
            Canvas { context, size in
                let types: [(PollenType, Color)] = [
                    (.alder, .brown), (.birch, .green), (.grass, .teal), (.ragweed, .orange)
                ]
                let peak = max(
                    ordered.flatMap { entry in types.compactMap { entry.value.value(of: $0.0) } }.max() ?? 1,
                    1
                )
                for (type, color) in types {
                    let values = ordered.compactMap { $0.value.value(of: type) }
                    guard values.count > 1 else { continue }
                    var path = Path()
                    for (index, value) in values.enumerated() {
                        let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                        let y = size.height - size.height * CGFloat(value / peak) * 0.92
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(color), lineWidth: 1.5)
                }
                context.draw(
                    Text(String(format: "%.0f grains/m³", peak)).font(.caption2).foregroundStyle(.secondary),
                    at: CGPoint(x: 60, y: 10)
                )
            }
            .frame(height: 150)
            .accessibilityIdentifier("detail.pollenChart")
        }
    }
}
