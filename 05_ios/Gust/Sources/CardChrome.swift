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

/// The shared full-width card: rounded surface, soft elevation, title row, content.
/// Half-size cards use `BlockShell`, which places them on upstream's 20 % guidelines.
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
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            content.padding(.horizontal, 16).padding(.bottom, 16)
        }
        // Fill the cell: paired cards are framed to a square, and a short
        // card must not leave its neighbour floating a few points lower.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BreezyTheme.surface(scheme))
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 4, y: 2)
        )
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
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

// MARK: - Square blocks

/// Upstream's half-size blocks, all ten of which are `1:1` cells whose content is
/// bounded by four guidelines at **20 %** and **80 %** (`container_main_*.xml`):
/// the title row sits on the top guide, the number fills the space below it, and the
/// label's baseline sits on the bottom guide.
///
/// Porting that geometry instead of stacking a title and a value in a `VStack` is what
/// stops the number drifting to the top of a circular card: on a `Corner.Full` cell the
/// guides are the only reason the content looks centred, and a hand-picked padding
/// looks wrong the moment the font or the screen changes.
///
/// The one difference between the two shapes: a circular block centres its title row
/// horizontally (a packed chain between the start and end guides), a rounded one leaves
/// it at the start guide.
struct BlockShell<Value: View, Footer: View>: View {
    @Environment(\.colorScheme) private var scheme

    var title: String
    var icon: String?
    var shape: CardShape = .extraLarge
    /// Drawn behind the content and outside the guides: upstream's `ArcProgress` on the
    /// air-quality block, which spans the whole square at a 5dp margin.
    var behind: AnyView?
    @ViewBuilder var value: Value
    @ViewBuilder var footer: Footer

    private var centred: Bool { shape == .circle }

    var body: some View {
        GeometryReader { geo in
            let insetX = geo.size.width * 0.2
            let insetY = geo.size.height * 0.2
            ZStack {
                surface
                if let behind {
                    behind
                }
                VStack(alignment: centred ? .center : .leading, spacing: 0) {
                    titleRow
                    Spacer(minLength: 0)
                    value
                        .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
                    Spacer(minLength: 0)
                    footer
                        .frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
                }
                .padding(.horizontal, insetX)
                .padding(.top, insetY)
                .padding(.bottom, insetY)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var surface: some View {
        switch shape {
        case .extraLarge:
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(BreezyTheme.surface(scheme))
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 4, y: 2)
        case .circle:
            Circle()
                .fill(BreezyTheme.surface(scheme))
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 4, y: 2)
        }
    }

    private var titleRow: some View {
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
