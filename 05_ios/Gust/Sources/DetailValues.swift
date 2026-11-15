//
//  DetailValues.swift
//  Gust
//
//  The value lists under each chart. Kept separate from the drawing code: one file
//  decides what a number is, the other decides where it goes.
//

import BreezyUnits
import SwiftUI

struct HourlyValueList: View {
    let weather: Weather
    let units: UnitPreferences

    private var rows: [HourlyForecast] {
        guard let reference = weather.current?.date else { return Array(weather.hourlyForecast.prefix(48)) }
        return Array(weather.hourlyForecast(from: reference).prefix(48))
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, hour in
                HStack {
                    Text(hour.date.localTime(in: weather.timeZone))
                        .font(.footnote)
                        .frame(width: 74, alignment: .leading)
                    Image(systemName: symbolName(for: hour.weatherCode))
                        .font(.caption)
                        .frame(width: 20)
                    Text(units.degrees(hour.temperature))
                        .font(.footnote.weight(.medium))
                        .frame(width: 42, alignment: .trailing)
                    Text(units.string(hour.precipitation))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 62, alignment: .trailing)
                    Spacer()
                    Text(units.string(hour.wind?.speed))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
                .background(index.isMultiple(of: 2) ? Color.clear : Color(.secondarySystemGroupedBackground))
                .accessibilityIdentifier("hourly.row.\(index)")
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct DailyValueList: View {
    let weather: Weather
    let units: UnitPreferences

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(weather.dailyForecast.enumerated()), id: \.offset) { index, day in
                HStack {
                    Text(index == 0 ? "Today" : day.date.shortWeekday(in: weather.timeZone))
                        .font(.footnote)
                        .frame(width: 58, alignment: .leading)
                    Text(units.degrees(day.temperatureMin))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                    Text(units.degrees(day.temperatureMax))
                        .font(.footnote.weight(.medium))
                        .frame(width: 44, alignment: .trailing)
                    Spacer()
                    if let probability = day.relativeHumidityMean {
                        Label(String(format: "%.0f %%", probability.inPercent), systemImage: "humidity")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let uv = day.uvIndexMax {
                        Label(String(format: "%.0f", uv), systemImage: "sun.max")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 5)
                .background(index.isMultiple(of: 2) ? Color.clear : Color(.secondarySystemGroupedBackground))
                .accessibilityIdentifier("dailyDetail.row.\(index)")
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MetricValueList: View {
    let weather: Weather
    let units: UnitPreferences
    let metric: MainCardKind

    private var rows: [(String, String)] {
        let reference = weather.current?.date ?? Date()
        let hours = Array(weather.hourlyForecast(from: reference).prefix(24))
        return hours.map { hour in
            let label = hour.date.localTime(in: weather.timeZone)
            switch metric {
            case .wind:
                let text = units.string(hour.wind?.speed)
                if let direction = hour.wind?.direction {
                    return (label, text + String(format: " · %.0f°", direction))
                }
                return (label, text)
            case .humidity: return (label, String(format: "%.0f %%", hour.relativeHumidity?.inPercent ?? .nan))
            case .uv: return (label, hour.uvIndex.map { String(format: "%.1f", $0) } ?? "—")
            case .visibility: return (label, units.string(hour.visibility))
            case .pressure: return (label, units.string(hour.pressure))
            case .precipitation: return (label, units.string(hour.precipitation))
            default: return (label, "—")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text(row.0).font(.footnote)
                    Spacer()
                    Text(row.1).font(.footnote.weight(.medium)).monospacedDigit()
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(index.isMultiple(of: 2) ? Color.clear : Color(.secondarySystemGroupedBackground))
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("detail.values")
    }
}

struct AirQualityValueList: View {
    let weather: Weather

    var body: some View {
        let entries = weather.airQuality.sorted { $0.key < $1.key }.prefix(24)
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                HStack {
                    Text(entry.key.localTime(in: weather.timeZone)).font(.footnote)
                    Spacer()
                    Text("AQI \(entry.value.index.map(String.init) ?? "—")")
                        .font(.footnote.weight(.medium))
                    Text(entry.value.pm25.map { String(format: "PM2.5 %.1f", $0.microgramsPerCubicMeter) } ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .trailing)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .background(index.isMultiple(of: 2) ? Color.clear : Color(.secondarySystemGroupedBackground))
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("detail.airValues")
    }
}
