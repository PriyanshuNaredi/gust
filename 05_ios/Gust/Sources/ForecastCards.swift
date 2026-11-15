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
    var shape: CardShape = .extraLarge
    @ViewBuilder let content: Content

    var body: some View {
        BreezyCard(title: title, icon: icon, shape: shape) { content }
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

/// The same families after dark. A sun icon at 23:00 is the kind of detail a user
/// notices immediately: the panel says "Nighttime" and the picture disagrees.
func nightSymbolName(for code: WeatherCode?) -> String {
    switch code {
    case .clear: return "moon.stars.fill"
    case .partlyCloudy: return "cloud.moon.fill"
    case .haze: return "moon.haze.fill"
    default: return symbolName(for: code)
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
                    .font(.system(size: 20, weight: .regular))
                    .accessibilityIdentifier("header.condition")
            }

            HStack(alignment: .top, spacing: 2) {
                Text(temperatureValue)
                    .font(.system(size: 140, weight: .regular))
                    .accessibilityIdentifier("header.temperature")
                Text(units.temperature == .fahrenheit ? "°F" : "°C")
                    .font(.system(size: 50, weight: .regular))
                    .padding(.top, 18)
            }
            .foregroundStyle(foreground)
            .accessibilityElement(children: .contain)

            if let feelsLike = weather.current?.apparentTemperature,
               feelsLike != weather.current?.temperature || feelsLike == nil {
                // Narrow width in upstream's header: whole degrees.
                Text("feels like " + units.degrees(feelsLike))
                    .font(.system(size: 14))
                    .accessibilityIdentifier("header.feelsLike")
            }

            if let range = dayNightRange {
                Text(range)
                    .font(.system(size: 14))
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
    @Environment(\.colorScheme) private var scheme
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
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme))
                                WeatherIcon(code: hour.weatherCode,
                                            daylight: weather.isDaylight(at: hour.date),
                                            size: 26)
                                Text(value(for: hour))
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                if tab == .conditions,
                                   let probability = hour.precipitationProbability,
                                   probability.inPercent >= 5 {
                                    Text(String(format: "%.0f%%", probability.inPercent))
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .frame(width: 54)
                        }
                    }
                    TrendChart(values: series, height: 56)
                        .frame(width: 54 * CGFloat(hours.count))
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TrendTab.allCases) { candidate in
                Button {
                    selection = candidate
                } label: {
                    Text(candidate.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selection == candidate
                                ? BreezyTheme.selectedTab
                                : BreezyTheme.unselectedTab.opacity(scheme == .dark ? 0.18 : 1),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            selection == candidate
                                ? Color.white
                                : BreezyTheme.onSurfaceVariant(scheme)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab.\(candidate.rawValue)")
            }
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
            // Upstream's daily block is a horizontally scrolling `TrendRecyclerView`
            // with one 67dp column per day, not a list of rows: the chart runs under
            // the columns and the columns scroll sideways.
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        ForEach(Array(weather.dailyForecast.enumerated()), id: \.offset) { index, day in
                            VStack(spacing: 4) {
                                Text(index == 0 ? "Today" : day.date.shortWeekday(in: weather.timeZone))
                                    .font(.system(size: 14))
                                    // Leaf identifiers only: a container identifier is
                                    // not addressable unless the container is itself an
                                    // accessibility element.
                                    .accessibilityIdentifier("daily.row.\(index)")
                                Text(day.date.formatted(Date.FormatStyle(timeZone: weather.timeZone).day()))
                                    .font(.system(size: 12))
                                    .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme))
                                WeatherIcon(code: dominantCode(day, index: index),
                                            daylight: true,
                                            size: 30)
                                switch tab {
                                case .conditions:
                                    Text(maxText(day))
                                        .font(.system(size: 15, weight: .medium))
                                    Text(minText(day))
                                        .font(.system(size: 14))
                                        .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme))
                                case .airQuality:
                                    Text(airQualityText(day)).font(.system(size: 15, weight: .medium))
                                case .wind:
                                    Text(windText(day)).font(.system(size: 15, weight: .medium))
                                }
                            }
                            .frame(width: 67)
                        }
                    }
                    TrendChart(values: dailySeries, height: 60)
                        .frame(width: 67 * CGFloat(weather.dailyForecast.count))
                }
            }
        }
        // No container identifier here: it merges the per-column identifiers
        // ("daily.row.0-…"). The card is addressable as cardLink.daily.
    }

    @Environment(\.colorScheme) private var scheme

    private var dailySeries: [Double] {
        weather.dailyForecast.map { day in
            switch tab {
            case .conditions:
                guard let high = day.temperatureMax else { return 0 }
                return units.temperature == .fahrenheit ? high.inFahrenheit : high.inCelsius
            case .airQuality:
                return Double(airQualityText(day)) ?? 0
            case .wind:
                guard let peak = weather.hourlyForecast
                    .filter({ Calendar(identifier: .gregorian).isDate($0.date, inSameDayAs: day.date) })
                    .compactMap({ $0.wind?.speed })
                    .max(by: { $0.inMetersPerSecond < $1.inMetersPerSecond }) else { return 0 }
                return units.speed == .milesPerHour ? peak.inMilesPerHour : peak.inKilometersPerHour
            }
        }
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
    var shape: CardShape = .extraLarge
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        BlockShell(title: title, icon: icon, shape: shape) {
            // Upstream splits a block's number from its unit ("1,022" + "hPa"), so
            // the number can be 45sp without the unit forcing it to shrink.
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(number)
                    .font(.system(size: 45, weight: .regular))
                    .foregroundStyle(BreezyTheme.onSurface(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let unit {
                    Text(unit)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(BreezyTheme.onSurface(scheme))
                }
            }
        } footer: {
            if let secondary {
                BlockSecondary(text: secondary)
            }
        }
        .accessibilityIdentifier("card.\(title.lowercased())")
    }

    private var split: (String, String?) {
        guard let first = lines.first else { return ("—", nil) }
        // "12 km/h" -> ("12", "km/h"); "1,022 hPa" -> ("1,022", "hPa").
        let parts = first.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return (first, nil) }
        return (String(parts[0]), String(parts[1]))
    }

    private var number: String { split.0 }
    private var unit: String? { split.1 }
    private var secondary: String? {
        let rest = lines.dropFirst().filter { !$0.isEmpty }
        return rest.isEmpty ? nil : rest.joined(separator: " · ")
    }
}

// MARK: - Precipitation

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
        BlockShell(title: "Precipitation", icon: "drop") {
            BlockValue(text: valueText)
        } footer: {
            BlockSecondary(text: labelText)
        }
        .accessibilityIdentifier("card.precipitation")
    }

    /// Upstream shows the half of the day you are in and names it after what is in it,
    /// so the label and the number cannot disagree.
    private var summary: PrecipitationSummary? {
        let now = weather.current?.date ?? Date()
        return PrecipitationSummary.today(from: weather.hourlyForecast, at: now, timeZone: weather.timeZone)
    }

    private var valueText: String {
        guard let summary else { return "—" }
        return units.string(summary.total)
    }

    private var labelText: String {
        summary?.label ?? "Precipitation"
    }
}

struct SunCard: View {
    let weather: Weather
    @Environment(\.colorScheme) private var scheme

    private var today: DailyForecast? { weather.dailyForecast.first }

    var body: some View {
        BlockShell(title: "Sun", icon: "sunrise") {
            AstroArc(
                progress: progress,
                marker: AnyView(Image(systemName: "sun.max.fill").foregroundStyle(.orange)),
                leading: today?.sunrise.map { $0.localTime(in: weather.timeZone) } ?? "—",
                trailing: today?.sunset.map { $0.localTime(in: weather.timeZone) } ?? "—"
            )
        } footer: {
            if let daylight = today?.daylightDuration {
                BlockSecondary(text: String(format: "%.0f h %02.0f min", floor(daylight / 3600),
                                            (daylight / 60).truncatingRemainder(dividingBy: 60)))
            }
        }
        .accessibilityIdentifier("card.sun")
    }

    /// Where the sun is between rise and set, 0…1; nil outside daylight.
    private var progress: Double? {
        guard let rise = today?.sunrise, let set = today?.sunset, set > rise else { return nil }
        let now = weather.current?.date ?? weather.refreshTime
        let fraction = now.timeIntervalSince(rise) / set.timeIntervalSince(rise)
        return min(max(fraction, 0), 1)
    }
}

/// Upstream draws a dashed semicircle with a marker for the current position
/// (`DetailsSunMoon`): the arc is the day, the marker is "now".
struct AstroArc: View {
    let progress: Double?
    let marker: AnyView
    let leading: String
    let trailing: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let size = geometry.size
                let radius = min(size.width / 2, size.height) - 6
                let center = CGPoint(x: size.width / 2, y: size.height - 4)

                Path { path in
                    path.addArc(center: center, radius: radius,
                                startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme).opacity(0.55))

                if let progress {
                    let angle = Double.pi * (1 + progress)
                    marker
                        .font(.system(size: 16))
                        .position(x: center.x + radius * cos(angle),
                                  y: center.y + radius * sin(angle))
                }
            }
            .frame(height: 54)

            HStack {
                Text(leading)
                Spacer()
                Text(trailing)
            }
            .font(.system(size: 14))
            .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme))
        }
    }
}

struct MoonCard: View {
    let weather: Weather

    private var phase: MoonPhase {
        MoonPhase(date: weather.current?.date ?? weather.refreshTime)
    }

    var body: some View {
        BlockShell(title: "Moon", icon: "moon") {
            AstroArc(
                progress: phase.illumination,
                marker: AnyView(Image(systemName: phase.symbolName).foregroundStyle(.secondary)),
                leading: String(format: "%.0f %%", phase.illumination * 100),
                trailing: phase.name
            )
        } footer: {
            EmptyView()
        }
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


// MARK: - Air quality: a ring, not a paragraph

struct AirQualityCard: View {
    let weather: Weather
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let quality = weather.airQuality(near: weather.current?.date ?? Date())
        BlockShell(
            title: "Air quality",
            icon: "aqi.medium",
            shape: .circle,
            behind: AnyView(
                // `ArcProgress` with a 5dp margin, `app:max="400"` and
                // `app:arc_angle="270"`: three quarters of a ring, the gap at the
                // bottom, not a full circle. A 360° ring reads as a dial; this reads
                // as the gauge the original draws.
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(BreezyTheme.onSurfaceVariant(scheme).opacity(0.18),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    Circle()
                        .trim(from: 0, to: 0.75 * fraction(quality?.index))
                        .stroke(levelColor(quality?.index),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round))
                }
                // Trim starts at 3 o'clock; -135° puts the first end at the bottom-left
                // and leaves the gap centred on the bottom.
                .rotationEffect(.degrees(135))
                .padding(5)
                .accessibilityHidden(true)
            )
        ) {
            BlockValue(text: quality?.index.map(String.init) ?? "—")
        } footer: {
            BlockSecondary(text: levelName(quality?.index))
        }
        .accessibilityIdentifier("card.airQuality")
    }

/// The ring is the index against the scale's top (250 = "extreme"), so a good day
    /// looks nearly empty rather than nearly full.
    private func fraction(_ index: Int?) -> Double {
        guard let index else { return 0 }
        return min(max(Double(index) / 250.0, 0), 1)
    }

    private func levelName(_ index: Int?) -> String {
        guard let index else { return "—" }
        switch index {
        case ..<20: return "Good"
        case ..<50: return "Fair"
        case ..<100: return "Poor"
        case ..<150: return "Very poor"
        case ..<250: return "Excessive"
        default: return "Extreme"
        }
    }

    private func levelColor(_ index: Int?) -> Color {
        guard let index else { return .secondary }
        switch index {
        case ..<20: return .green
        case ..<50: return .yellow
        case ..<100: return .orange
        case ..<150: return .red
        default: return .purple
        }
    }
}

// MARK: - Wind, with the direction it comes from

struct WindCard: View {
    let weather: Weather
    let units: UnitPreferences
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let wind = weather.current?.wind
        BlockShell(title: "Wind", icon: "wind", shape: .circle) {
            HStack(spacing: 4) {
                Text(units.string(wind?.speed))
                    .font(.system(size: 24, weight: .regular))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityIdentifier("wind.speed")
                if let degree = wind?.direction {
                    // Upstream rotates an arrow so its head points where the wind is
                    // going; "From N" is the same fact in words.
                    Image(systemName: "location.north.fill")
                        .font(.caption)
                        .rotationEffect(.degrees(degree + 180))
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            BlockSecondary(text: detail(wind))
                .accessibilityIdentifier("wind.detail")
        }
        .accessibilityIdentifier("card.wind")
    }

    private func detail(_ wind: Wind?) -> String {
        guard let wind else { return "—" }
        if let speed = wind.speed, let gusts = wind.gusts, gusts.inMetersPerSecond > speed.inMetersPerSecond {
            return "Gusts: " + units.string(gusts)
        }
        guard let degree = wind.direction else { return "—" }
        guard (0...360).contains(degree) else { return "Variable" }
        return "From " + compassPoint(degree)
    }

    /// Sixteen-point compass, the same resolution upstream's `getDirection(short:)` uses.
    private func compassPoint(_ degrees: Double) -> String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) + 11.25) / 22.5) % 16
        return points[index]
    }
}

// MARK: - Pollen, coloured by its own level

struct PollenCard: View {
    let weather: Weather

    var body: some View {
        let pollen = weather.pollen(near: weather.current?.date ?? Date())
        BlockShell(title: "Pollen", icon: "leaf") {
            if weather.pollen.isEmpty {
                BlockValue(text: "—")
            } else if let worst = pollen?.worstType, worst.index > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pollenColor(worst.index))
                        .frame(width: 10, height: 10)
                    Text(worst.type.rawValue.capitalized)
                        .font(.system(size: 22, weight: .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .accessibilityIdentifier("pollen.level")
            } else {
                BlockValue(text: "None")
            }
        } footer: {
            if weather.pollen.isEmpty {
                BlockSecondary(text: "no coverage here")
            } else if let worst = pollen?.worstType, worst.index > 0 {
                BlockSecondary(text: PollenIndexCalculator.name(for: worst.index) ?? "")
            } else {
                BlockSecondary(text: "no pollen detected")
            }
        }
        .accessibilityIdentifier("card.pollen")
    }

    private func pollenColor(_ index: Int) -> Color {
        guard let colour = PollenIndexCalculator.color(for: index) else { return .secondary }
        return Color(red: colour.red / 255, green: colour.green / 255, blue: colour.blue / 255)
    }
}
