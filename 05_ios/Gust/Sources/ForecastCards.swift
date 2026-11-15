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
    let units: UnitPreferences

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.footnote.weight(.semibold))
                Text(relativeRefreshTime)
                    .font(.footnote.weight(.semibold))
                    .accessibilityIdentifier("header.refreshTime")
                Spacer()
            }
            .padding(.bottom, 6)

            if let condition = conditionText {
                Text(condition)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("header.condition")
            }

            HStack(alignment: .top, spacing: 2) {
                Text(temperatureValue)
                    .font(.system(size: 92, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("header.temperature")
                Text(units.temperature == .fahrenheit ? "°F" : "°C")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .padding(.top, 10)
            }
            .foregroundStyle(foreground)
            .accessibilityElement(children: .contain)

            if let feelsLike = weather.current?.apparentTemperature,
               feelsLike != weather.current?.temperature || feelsLike == nil {
                // Narrow width in upstream's header: whole degrees.
                Text("feels like " + units.degrees(feelsLike))
                    .font(.headline.weight(.medium))
                    .accessibilityIdentifier("header.feelsLike")
            }

            if let range = dayNightRange {
                Text(range)
                    .font(.subheadline)
                    .padding(.top, 2)
                    .accessibilityIdentifier("header.dayNight")
            }
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.header")
    }

    /// Upstream picks one text colour for the whole header: black on the pale day
    /// colours, white on the darkened night ones.
    private var foreground: Color {
        weather.isDaylight() ? Color.black.opacity(0.86) : .white
    }

    private var temperatureValue: String {
        guard let temperature = weather.current?.temperature else { return "—" }
        let value = units.temperature == .fahrenheit ? temperature.inFahrenheit : temperature.inCelsius
        return String(format: "%.0f", value)
    }

    private var conditionText: String? {
        weather.current?.weatherCode.map(familyLabel)
    }

    private var relativeRefreshTime: String {
        let minutes = Int(Date().timeIntervalSince(weather.refreshTime) / 60)
        switch minutes {
        case ..<1: return "just now"
        case 1: return "1 min ago"
        default: return "\(minutes) mins ago"
        }
    }

    /// Upstream's `getTemperatureRangeSummary`: "Day: 24° • Night: 14°".
    private var dayNightRange: String? {
        guard let today = weather.dailyForecast.first else { return nil }
        // The daily list drops the last day, so the first entry is today.
        let formatter = units.temperature == .fahrenheit
        guard let high = today.temperatureMax, let low = today.temperatureMin else { return nil }
        let highValue = formatter ? high.inFahrenheit : high.inCelsius
        let lowValue = formatter ? low.inFahrenheit : low.inCelsius
        return String(format: "Day: %.0f°  •  Night: %.0f°", highValue, lowValue)
    }

}

// MARK: - Hourly

/// Upstream's hourly card is a trend with tabs, not a plain strip: the same hours in
/// the same order, seen three ways.
enum TrendTab: String, CaseIterable, Identifiable {
    case conditions = "Conditions"
    case airQuality = "Air quality"
    case wind = "Wind"

    var id: String { rawValue }
}

struct HourlyCard: View {
    let weather: Weather
    let units: UnitPreferences
    @State private var tab: TrendTab = .conditions

    private var hours: [HourlyForecast] {
        let from = weather.current?.date ?? weather.hourlyForecast.first?.date ?? Date()
        return Array(weather.hourlyForecast(from: from).prefix(24))
    }

    var body: some View {
        CardShell(title: "Hourly forecast", icon: "clock") {
            TrendTabs(selection: $tab)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                            VStack(spacing: 3) {
                                Text(index == 0 ? "Now" : hour.date.localTime(in: weather.timeZone))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Image(systemName: symbolName(for: hour.weatherCode))
                                    .font(.footnote)
                                Text(value(for: hour))
                                    .font(.caption.weight(.medium))
                                if tab == .conditions,
                                   let probability = hour.precipitationProbability,
                                   probability.inPercent >= 5 {
                                    Text(String(format: "%.0f%%", probability.inPercent))
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .frame(width: 46)
                        }
                    }
                    TrendChart(values: series, height: 56)
                        .frame(width: 46 * CGFloat(hours.count))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("hourly.strip")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.hourly")
    }

    private var series: [Double] {
        hours.map { hour -> Double in
            switch tab {
            case .conditions: return temperatureValue(hour)
            case .airQuality:
                return Double(weather.airQuality(near: hour.date)?.index ?? 0)
            case .wind:
                let speed = hour.wind?.speed
                return units.speed == .milesPerHour ? (speed?.inMilesPerHour ?? 0) : (speed?.inKilometersPerHour ?? 0)
            }
        }
    }

    private func temperatureValue(_ hour: HourlyForecast) -> Double {
        guard let temperature = hour.temperature else { return 0 }
        return units.temperature == .fahrenheit ? temperature.inFahrenheit : temperature.inCelsius
    }

    private func value(for hour: HourlyForecast) -> String {
        switch tab {
        case .conditions: return units.degrees(hour.temperature)
        case .airQuality:
            guard let index = weather.airQuality(near: hour.date)?.index else { return "—" }
            return String(index)
        case .wind: return units.string(hour.wind?.speed)
        }
    }
}

struct TrendTabs: View {
    @Binding var selection: TrendTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TrendTab.allCases) { candidate in
                Button {
                    selection = candidate
                } label: {
                    Text(candidate.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            selection == candidate ? Color.accentColor.opacity(0.16) : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(selection == candidate ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(candidate.rawValue)")
            }
            Spacer()
        }
    }
}

/// A line with faint grid lines and its extremes labelled, which is what the upstream
/// trend charts show. Not a normalised sparkline: the y-scale is the series' own range
/// so the labels mean something.
struct TrendChart: View {
    let values: [Double]
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let low = values.min() ?? 0
            let high = values.max() ?? 1
            let span = max(high - low, 0.5)

            for fraction in [0.0, 0.5, 1.0] {
                var grid = Path()
                let y = size.height * fraction
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(grid, with: .color(.secondary.opacity(0.15)), lineWidth: 0.5)
            }

            let gutter: CGFloat = 34
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = gutter + (size.width - gutter) * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height - (size.height - 12) * CGFloat((value - low) / span) - 6
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(.accentColor), lineWidth: 2)
            context.draw(
                Text(String(format: "%.0f", high)).font(.caption2).foregroundStyle(.secondary),
                at: CGPoint(x: gutter / 2, y: 8)
            )
            context.draw(
                Text(String(format: "%.0f", low)).font(.caption2).foregroundStyle(.secondary),
                at: CGPoint(x: gutter / 2, y: size.height - 8)
            )
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct DailyCard: View {
    let weather: Weather
    let units: UnitPreferences
    @State private var tab: TrendTab = .conditions

    var body: some View {
        CardShell(title: "Daily forecast", icon: "calendar") {
            TrendTabs(selection: $tab)
            VStack(spacing: 6) {
                ForEach(Array(weather.dailyForecast.enumerated()), id: \.offset) { index, day in
                    HStack(spacing: 8) {
                        Text(index == 0 ? "Today" : day.date.shortWeekday(in: weather.timeZone))
                            .font(.footnote)
                            .frame(width: 54, alignment: .leading)
                        switch tab {
                        case .conditions:
                            Image(systemName: symbolName(for: dominantCode(day, index: index)))
                                .font(.caption)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            Text(minText(day))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(width: 46, alignment: .trailing)
                            TemperatureBar(day: day, allDays: weather.dailyForecast)
                                .frame(height: 4)
                            Text(maxText(day))
                                .font(.footnote.weight(.medium))
                                .frame(width: 46, alignment: .leading)
                        case .airQuality:
                            Text("AQI")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(airQualityText(day))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                        case .wind:
                            Text("Wind")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(windText(day))
                                .font(.footnote.weight(.medium))
                        }
                    }
                    .accessibilityIdentifier("daily.row.\(index)")
                }
            }
        }
        // No container identifier here: it merges the per-row identifiers
        // ("daily.row.0-daily.row.0-…"). The card is addressable as cardLink.daily.
    }

    /// The day's weather at the hour this card starts, which is what upstream's icon
    /// column shows: the hourly entry nearest midday is a fair stand-in for a daily row.
    private func dominantCode(_ day: DailyForecast, index: Int) -> WeatherCode? {
        guard let noon = day.date.addingTimeInterval(12 * 3600) as Date? else { return nil }
        let candidates = weather.hourlyForecast.filter {
            Calendar(identifier: .gregorian).isDate($0.date, inSameDayAs: day.date)
        }
        return candidates.min { abs($0.date.timeIntervalSince(noon)) < abs($1.date.timeIntervalSince(noon)) }?.weatherCode
    }

    private func airQualityText(_ day: DailyForecast) -> String {
        let hours = weather.airQuality.filter {
            Calendar(identifier: .gregorian).isDate($0.key, inSameDayAs: day.date)
        }
        guard let peak = hours.values.compactMap({ $0.index }).max() else { return "—" }
        return String(peak)
    }

    private func windText(_ day: DailyForecast) -> String {
        let hours = weather.hourlyForecast.filter {
            Calendar(identifier: .gregorian).isDate($0.date, inSameDayAs: day.date)
        }
        guard let peak = hours.map(\.wind?.speed).compactMap({ $0 }).max(by: { $0.inMetersPerSecond < $1.inMetersPerSecond })
        else { return "—" }
        return units.string(peak)
    }

    private func minText(_ day: DailyForecast) -> String { units.degrees(day.temperatureMin) }
    private func maxText(_ day: DailyForecast) -> String { units.degrees(day.temperatureMax) }
}

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
    let units: UnitPreferences

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
        return units.string(total.millimeters)
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
