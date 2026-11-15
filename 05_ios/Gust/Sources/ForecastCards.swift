//
//  ForecastCards.swift
//  Gust
//
//  The individual cards. Styling follows the Android panels closely enough to
//  compare side by side: rounded card, title row, then content — but iOS-native
//  metrics rather than a pixel copy of Compose.
//

import BreezyUnits
import SwiftUI

// MARK: - Formatting

/// Every time in the UI is formatted in the *location's* zone. Using the device's
/// zone made a Berlin sunrise show as 1:26 AM on a simulator set to Pacific time.
extension Date {
    func localTime(in zone: TimeZone, includeMinutes: Bool = true) -> String {
        formatted(Date.FormatStyle(
            date: .omitted,
            time: includeMinutes ? .shortened : .shortened,
            timeZone: zone
        ))
    }

    func shortWeekday(in zone: TimeZone) -> String {
        formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated))
    }
}

// MARK: - Shared chrome

struct CardShell<Content: View>: View {
    let title: String?
    let icon: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// SF Symbol for a Breezy weather family. Not a pixel-art match for upstream's
/// hand-drawn icons; that swap belongs with the icon-set slice.
func symbolName(for code: WeatherCode?) -> String {
    switch code {
    case .clear: return "sun.max.fill"
    case .partlyCloudy: return "cloud.sun.fill"
    case .cloudy: return "cloud.fill"
    case .rain: return "cloud.rain.fill"
    case .snow: return "cloud.snow.fill"
    case .sleet: return "cloud.sleet.fill"
    case .hail: return "cloud.hail.fill"
    case .thunder: return "cloud.bolt.fill"
    case .thunderstorm: return "cloud.bolt.rain.fill"
    case .wind: return "wind"
    case .fog: return "cloud.fog.fill"
    case .haze: return "sun.haze.fill"
    case nil: return "questionmark"
    }
}

func familyLabel(_ code: WeatherCode?) -> String {
    switch code {
    case .clear: return "Clear"
    case .partlyCloudy: return "Partly cloudy"
    case .cloudy: return "Cloudy"
    case .rain: return "Rain"
    case .snow: return "Snow"
    case .sleet: return "Sleet"
    case .hail: return "Hail"
    case .thunder: return "Thunder"
    case .thunderstorm: return "Thunderstorm"
    case .wind: return "Wind"
    case .fog: return "Fog"
    case .haze: return "Haze"
    case nil: return "—"
    }
}

// MARK: - Header

struct HeaderCard: View {
    let weather: Weather
    let place: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(place)
                    .font(.headline)
                Spacer()
                Image(systemName: symbolName(for: weather.current?.weatherCode))
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(temperatureText)
                    .font(.system(size: 44, weight: .thin, design: .rounded))
                    .accessibilityIdentifier("header.temperature")
                VStack(alignment: .leading, spacing: 2) {
                    Text(familyLabel(weather.current?.weatherCode))
                        .font(.subheadline)
                    if let feelsLike = weather.current?.apparentTemperature {
                        Text(String(format: "feels like %.1f °C", feelsLike.inCelsius))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.header")
    }

    private var temperatureText: String {
        guard let temperature = weather.current?.temperature else { return "—" }
        return String(format: "%.1f°", temperature.inCelsius)
    }
}

// MARK: - Hourly

struct HourlyCard: View {
    let weather: Weather

    /// Twelve hours from the current one, as upstream's hourly card shows a strip.
    private var hours: [HourlyForecast] {
        let from = weather.current?.date ?? weather.hourlyForecast.first?.date ?? Date()
        return Array(weather.hourlyForecast(from: from).prefix(12))
    }

    var body: some View {
        CardShell(title: "Hourly", icon: "clock") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                        VStack(spacing: 4) {
                            Text(index == 0 ? "Now" : hour.date.localTime(in: weather.timeZone))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Image(systemName: symbolName(for: hour.weatherCode))
                                .font(.body)
                            Text(hour.temperature.map { String(format: "%.0f°", $0.inCelsius) } ?? "—")
                                .font(.footnote.weight(.medium))
                            if let probability = hour.precipitationProbability, probability.inPercent >= 5 {
                                Text(String(format: "%.0f%%", probability.inPercent))
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(width: 40)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.hourly")
    }
}

// MARK: - Daily

struct DailyCard: View {
    let weather: Weather

    var body: some View {
        CardShell(title: "Daily", icon: "calendar") {
            VStack(spacing: 6) {
                ForEach(Array(weather.dailyForecast.enumerated()), id: \.offset) { index, day in
                    HStack(spacing: 8) {
                        Text(index == 0 ? "Today" : day.date.shortWeekday(in: weather.timeZone))
                            .font(.footnote)
                            .frame(width: 54, alignment: .leading)
                        Image(systemName: symbolName(for: nil))
                            .font(.caption)
                            .hidden()
                        Text(minText(day))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                        TemperatureBar(day: day, allDays: weather.dailyForecast)
                            .frame(height: 4)
                        Text(maxText(day))
                            .font(.footnote.weight(.medium))
                            .frame(width: 46, alignment: .leading)
                    }
                    .accessibilityIdentifier("daily.row.\(index)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.daily")
    }

    private func minText(_ day: DailyForecast) -> String {
        day.temperatureMin.map { String(format: "%.0f°", $0.inCelsius) } ?? "—"
    }

    private func maxText(_ day: DailyForecast) -> String {
        day.temperatureMax.map { String(format: "%.0f°", $0.inCelsius) } ?? "—"
    }
}

/// The high/low range bar, scaled to the whole forecast rather than to the day.
struct TemperatureBar: View {
    let day: DailyForecast
    let allDays: [DailyForecast]

    var body: some View {
        GeometryReader { geometry in
            let lows = allDays.compactMap { $0.temperatureMin?.inCelsius }
            let highs = allDays.compactMap { $0.temperatureMax?.inCelsius }
            let scaleLow = lows.min() ?? 0
            let scaleHigh = highs.max() ?? 1
            let span = max(scaleHigh - scaleLow, 0.1)

            let low = day.temperatureMin?.inCelsius ?? scaleLow
            let high = day.temperatureMax?.inCelsius ?? scaleLow
            let start = (low - scaleLow) / span
            let width = max((high - low) / span, 0.02)

            Capsule()
                .fill(Color.accentColor.opacity(0.25))
                .overlay(alignment: .leading) {
                    GeometryReader { inner in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(inner.size.width * width, 3))
                            .offset(x: inner.size.width * start)
                    }
                }
                .frame(height: geometry.size.height)
        }
        .accessibilityIdentifier("daily.bar")
    }
}

// MARK: - Half-size cards

struct MetricHalfCard: View {
    let title: String
    let icon: String
    let lines: [String]

    var body: some View {
        CardShell(title: title, icon: icon) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(index == 0 ? .title3.weight(.regular) : .caption)
                        .foregroundStyle(index == 0 ? .primary : .secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.\(title.lowercased())")
    }
}
// MARK: - Precipitation

/// Nowcast strip: the next two hours in 15-minute steps, drawn with `Canvas`
/// rather than a chart library, because upstream draws it by hand too and the shape
/// (dense bars, no axes) is the point.
struct NowcastCard: View {
    let nowcast: Nowcast
    let zone: TimeZone

    private var title: String {
        switch nowcast.state {
        case .starting: return "Rain starting"
        case .continuing: return "Rain continuing"
        case .stopping: return "Rain stopping"
        case .none: return "Precipitation"
        }
    }

    var body: some View {
        CardShell(title: title, icon: "cloud.rain") {
            VStack(alignment: .leading, spacing: 6) {
                Canvas { context, size in
                    // Absolute scale like upstream: the y-axis tops out at "heavy"
                    // (15 mm/h) so a drizzle stays a drizzle instead of filling the
                    // card the way normalisation would.
                    let steps = nowcast.window(maxSteps: 12)
                    let rates = steps.map {
                        Nowcast.millimetersPerHour(of: $0, suggesting: nowcast.stepInterval)
                    }
                    let scale = max(rates.max() ?? 0, 15.0)
                    guard !steps.isEmpty, size.width > 0 else { return }
                    let slot = size.width / CGFloat(max(steps.count, 1))
                    for (index, rate) in rates.enumerated() {
                        let value = rate / scale
                        let height = max(CGFloat(value) * size.height, rate > 0 ? 2 : 0.5)
                        let rect = CGRect(
                            x: slot * CGFloat(index) + 1,
                            y: size.height - height,
                            width: max(slot - 2, 1),
                            height: height
                        )
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 1.5),
                            with: .color(.blue.opacity(value > 0 ? 0.85 : 0.18))
                        )
                    }
                }
                .frame(height: 34)

                HStack {
                    Text(nowcast.firstWetDate.map { $0.localTime(in: zone) } ?? "—")
                    Spacer()
                    // The window starts at the first wet step when rain is later than
                    // the strip's head, so the label has to say which window this is.
                    Text(nowcast.window(maxSteps: 12).first
                        .map { "from " + $0.date.localTime(in: zone) } ?? "")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.nowcast")
    }
}

/// Today's precipitation total.
///
/// DEVIATION from upstream: Breezy splits this card into day and night halves and
/// looks at the previous night, which needs the sun's rise/set times. This port
/// shows a single "today" total until the astronomy port lands; see the parity
/// ledger in 02_parity/PARITY_SPEC.md.
struct PrecipitationCard: View {
    let weather: Weather

    var body: some View {
        CardShell(title: "Precipitation", icon: "drop") {
            VStack(alignment: .leading, spacing: 2) {
                Text(totalText)
                    .font(.title3.weight(.regular))
                Text(probabilityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.precipitation")
    }

    private var todayHours: [HourlyForecast] {
        guard let reference = weather.current?.date ?? weather.hourlyForecast.first?.date else { return [] }
        let calendar = Calendar.current
        return weather.hourlyForecast.filter { calendar.isDate($0.date, inSameDayAs: reference) }
    }

    private var totalText: String {
        let total = todayHours.compactMap { $0.precipitation?.inMillimeters }.reduce(0, +)
        return String(format: "%.1f mm", total)
    }

    private var probabilityText: String {
        let peak = todayHours.compactMap { $0.precipitationProbability?.inPercent }.max()
        guard let peak else { return "—" }
        return String(format: "chance %.0f %%", peak)
    }
}

// MARK: - Sun, moon, clock, footer

struct SunCard: View {
    let weather: Weather

    private var today: DailyForecast? { weather.dailyForecast.first }

    var body: some View {
        CardShell(title: "Sun", icon: "sunrise") {
            VStack(alignment: .leading, spacing: 4) {
                row("rise", today?.sunrise)
                row("set", today?.sunset)
                if let daylight = today?.daylightDuration {
                    Text(String(format: "%.0f h %02.0f", floor(daylight / 3600), (daylight / 60).truncatingRemainder(dividingBy: 60)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.sun")
    }

    private func row(_ label: String, _ date: Date?) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(date.map { $0.localTime(in: weather.timeZone) } ?? "—")
                .font(.callout.weight(.medium))
        }
    }
}

struct MoonCard: View {
    let weather: Weather

    private var phase: MoonPhase {
        MoonPhase(date: weather.current?.date ?? weather.refreshTime)
    }

    var body: some View {
        CardShell(title: "Moon", icon: "moon") {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: phase.symbolName)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f %%", phase.illumination * 100))
                        .font(.title3.weight(.regular))
                }
                Text(phase.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.moon")
    }
}

/// Local time at the place, which is the one card that cannot be wrong: it comes
/// from the device clock and the coordinate's time zone, not from the source.
struct ClockCard: View {
    let timeZone: TimeZone

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            CardShell(title: "Local time", icon: "clock") {
                Text(context.date.formatted(
                    Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)
                ))
                    .font(.title3.weight(.regular))
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.clock")
    }
}

/// Attribution and refresh time. Not optional: the data is CC BY 4.0 and the app is
/// an LGPL derivative, so the credit belongs on the main screen, not only in About.
struct FooterCard: View {
    let weather: Weather
    let place: String

    var body: some View {
        VStack(spacing: 2) {
            Text("Weather data by Open-Meteo (CC BY 4.0)")
                .font(.caption2)
            Text("Gust — a port of Breezy Weather 6.2.2 (LGPL-3.0)")
                .font(.caption2)
            Text("Updated " + weather.refreshTime.localTime(in: weather.timeZone))
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityIdentifier("card.footer")
    }
}
