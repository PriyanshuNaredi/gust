//
//  CardChrome.swift
//  Gust
//
//  Card chrome copied from the Android main screen rather than from iOS defaults.
//  Upstream gives each block a *shape* (`ShapeAppearance.Material3.Corner.*` on the
//  MaterialCardView in `container_main_*.xml`), a 16dp content inset, a 16sp bold
//  title with a 16dp icon, and block numbers at 45sp. Using SwiftUI's grouped-list
//  look instead is what made the first version read as "a weather app" rather than
//  "this weather app".
//

import BreezyUnits
import SwiftUI

// MARK: - Palette

/// Material 3 baseline surface roles, spelled out because the port paints its own
/// backdrop and cannot rely on `Color(.systemBackground)` matching it.
enum BreezyTheme {
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.11, green: 0.11, blue: 0.12)
            : Color(red: 0.98, green: 0.98, blue: 0.99)
    }

    static func onSurface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.93) : Color(white: 0.13)
    }

    static func onSurfaceVariant(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.78) : Color(white: 0.38)
    }

    /// Upstream's selected trend tab: blue fill, white label.
    static let selectedTab = Color(red: 0.20, green: 0.42, blue: 0.78)
    static let unselectedTab = Color(red: 0.85, green: 0.85, blue: 0.90)
}

// MARK: - Shapes

/// `app:shapeAppearance` per block, from `container_main_*.xml`:
/// air quality, pressure, visibility and wind use `Corner.Full` (a circle on the
/// square half-size cell); everything else uses `Corner.ExtraLarge` (28dp).
enum CardShape {
    case extraLarge
    case circle

    var cornerRadius: CGFloat? {
        self == .extraLarge ? 28 : nil
    }
}

extension MainCardKind {
    var shape: CardShape {
        switch self {
        case .airQuality, .pressure, .visibility, .wind: return .circle
        default: return .extraLarge
        }
    }
}

// MARK: - Card

/// The shared card: rounded surface, soft elevation, title row, content.
struct BreezyCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme

    let title: String?
    let icon: String?
    var shape: CardShape = .extraLarge
    /// Circular cards inset their content to 20 % of the square, as upstream's
    /// `block_*_guideline` constraints do.
    var insetForCircle: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            switch shape {
            case .extraLarge:
                VStack(alignment: .leading, spacing: 8) { titleRow; content.padding(.horizontal, 16).padding(.bottom, 16) }
                    // Fill the cell: paired cards are framed to a square, and a short
                    // card must not leave its neighbour floating a few points lower.
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(BreezyTheme.surface(scheme))
                            .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 4, y: 2)
                    )
            case .circle:
                // Upstream's circular blocks are square cells with the content inset to
                // 20 % of the square. Drawing the circle *behind* a taller VStack put the
                // title outside the circle and let long values spill over its edge.
                ZStack {
                    Circle()
                        .fill(BreezyTheme.surface(scheme))
                        .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 4, y: 2)
                    VStack(spacing: 4) {
                        titleRow
                        content
                    }
                    .padding(.horizontal, 24)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var titleRow: some View {
        if let title {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .regular))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme))
            .padding(.horizontal, shape == .extraLarge ? 16 : 0)
            .padding(.top, shape == .extraLarge ? 16 : 0)
        }
    }
}

// MARK: - Type

/// `Weather.TextAppearance.MainBlock.NumberDigit`: 45sp.
struct BlockValue: View {
    @Environment(\.colorScheme) private var scheme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 45, weight: .regular))
            .foregroundStyle(BreezyTheme.onSurface(scheme))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
    }
}

/// `content_text_size` (14sp) for the line under a block value.
struct BlockSecondary: View {
    @Environment(\.colorScheme) private var scheme
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme))
            .lineLimit(2)
    }
}

// MARK: - Weather icon

/// Upstream's own 256 px weather artwork (`weather_<code>_<day|night>.png`), which
/// the port now ships under `Resources/WeatherIcons`. SF Symbols were the single
/// biggest reason the first version did not look like the Android app.
struct WeatherIcon: View {
    let code: WeatherCode?
    let daylight: Bool
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let artwork = Self.artwork(for: code, day: daylight) {
                Image(uiImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                // A missing file shows a symbol rather than an empty space: the first
                // version used `Image(name)` and a bad name looked like padding.
                Image(systemName: "cloud.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static var cache: [String: UIImage] = [:]

    /// `UIImage(named:)` resolves through the asset catalogue first and did not find
    /// loose files copied by the resource build phase; the path lookup is unambiguous.
    private static func artwork(for code: WeatherCode?, day: Bool) -> UIImage? {
        let name = WeatherIcons.name(for: code ?? .cloudy, day: day)
        if let hit = cache[name] { return hit }
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let image = UIImage(contentsOfFile: path) else { return nil }
        cache[name] = image
        return image
    }
}
