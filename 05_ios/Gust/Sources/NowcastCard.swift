//
//  NowcastCard.swift
//  Gust
//
//  The precipitation nowcast, drawn the way `PrecipitationNowcastViewHolder` draws it:
//  a title, a one-line description, and a 150pt chart of five-minute buckets with a
//  three-tick time axis and the light/medium/heavy threshold lines.
//
//  Everything numeric comes from `BreezyUnits.NowcastChart` (bucket span, threshold
//  law, the two sentences). This file is geometry only.
//

import BreezyUnits
import SwiftUI

struct NowcastCard: View {
    let nowcast: Nowcast
    let zone: TimeZone
    /// Upstream picks the bar colour with `WeatherViewController.isDaylight(location)`,
    /// i.e. the weather's own daylight, not the phone's clock or the theme.
    let daylight: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        CardShell(title: nowcast.title, icon: "umbrella") {
            VStack(alignment: .leading, spacing: 6) {
                Text(nowcast.summary(zone: zone))
                    .font(.system(size: 14))
                    .foregroundStyle(BreezyTheme.onSurfaceVariant(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                NowcastChart(nowcast: nowcast, zone: zone, daylight: daylight)
                    .frame(height: 150)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("card.nowcast")
    }
}

private struct NowcastChart: View {
    let nowcast: Nowcast
    let zone: TimeZone
    let daylight: Bool

    @Environment(\.colorScheme) private var scheme

    /// `RainImplementor.getThemeColor(TYPE_RAIN, daylight)`; the night value is that
    /// colour run through `getBrighterColor` (saturation −0.25, value +0.25).
    private var barColour: Color {
        daylight ? Color(.sRGB, red: 66 / 255, green: 151 / 255, blue: 231 / 255)
                 : Color(.sRGB, red: 107 / 255, green: 145 / 255, blue: 207 / 255)
    }

    /// `colorTextGrey` on a light background, `colorTextGrey2nd` on a dark one.
    private var lineColour: Color {
        scheme == .dark
            ? Color(.sRGB, white: 0.70, opacity: 0.55)
            : Color(.sRGB, white: 0.30, opacity: 0.35)
    }

    private var labelColour: Color {
        scheme == .dark
            ? Color(.sRGB, white: 0.70, opacity: 1)
            : Color(.sRGB, white: 0.30, opacity: 1)
    }

    var body: some View {
        Canvas { context, size in
            let labelBand: CGFloat = 16
            let plotTop: CGFloat = 2
            let plotBottom = size.height - labelBand
            let plotHeight = max(plotBottom - plotTop, 1)

            let rates = nowcast.chartRates()
            guard !rates.isEmpty, size.width > 0 else { return }

            let maximum = nowcast.chartMaximum
            let slot = size.width / CGFloat(rates.count)

            // Threshold lines first, so the bars sit on top of them.
            for threshold in Nowcast.thresholds(maximum: maximum) {
                let fraction = threshold.millimetersPerHour / maximum
                let y = plotBottom - CGFloat(fraction) * plotHeight
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(lineColour), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                // Above the line, except at the top of the plot where that puts the
                // text outside the canvas: the heavy label was the one clipped.
                let nearTop = y < 14
                context.draw(
                    Text(threshold.label)
                        .font(.system(size: 10))
                        .foregroundStyle(labelColour),
                    at: CGPoint(x: size.width - 2, y: nearTop ? y + 1 : y - 1),
                    anchor: nearTop ? .topTrailing : .bottomTrailing
                )
            }

            // Five-minute buckets. A dry bucket draws nothing, exactly like a
            // zero-height column: the absence is the information.
            for (index, rate) in rates.enumerated() {
                guard rate.millimetersPerHour > 0 else { continue }
                let fraction = min(rate.millimetersPerHour / maximum, 1)
                let height = max(CGFloat(fraction) * plotHeight, 2)
                let rect = CGRect(
                    x: CGFloat(index) * slot + 0.5,
                    y: plotBottom - height,
                    width: max(slot - 1, 1),
                    height: height
                )
                let radius = min(rect.width, rect.height) * 0.15
                context.fill(
                    Path(roundedRect: rect, cornerRadius: radius),
                    with: .color(barColour)
                )
            }

            // Time axis: a baseline and three labels — start, middle, end — as
            // `SpecificHorizontalAxisItemPlacer` places them.
            var axis = Path()
            axis.move(to: CGPoint(x: 0, y: plotBottom))
            axis.addLine(to: CGPoint(x: size.width, y: plotBottom))
            context.stroke(axis, with: .color(lineColour), lineWidth: 1)

            // Upstream's maxX is the last step's *ending* date, so the axis runs from
            // the first bucket to one bucket past the last, and the middle tick is at
            // exactly half the span rather than at the median bucket.
            guard let start = rates.first?.date, let last = rates.last?.date else { return }
            let end = last.addingTimeInterval(Nowcast.bucketSeconds)
            let middle = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
            let ticks: [(fraction: CGFloat, label: String, anchor: UnitPoint)] = [
                (0, Nowcast.time(start, zone: zone), .topLeading),
                (0.5, Nowcast.time(middle, zone: zone), .top),
                (1, Nowcast.time(end, zone: zone), .topTrailing)
            ]
            for tick in ticks {
                context.draw(
                    Text(tick.label)
                        .font(.system(size: 11))
                        .foregroundStyle(labelColour),
                    at: CGPoint(x: size.width * tick.fraction, y: plotBottom + 3),
                    anchor: tick.anchor
                )
            }
        }
        .accessibilityHidden(true)
    }
}
