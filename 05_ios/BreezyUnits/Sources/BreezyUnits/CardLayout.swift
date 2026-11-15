//
//  CardLayout.swift
//  BreezyUnits
//
//  The main screen is a list of cards, and which cards are "half size" is a
//  layout *rule*, not a styling choice. Ported from
//  `ui/main/adapters/main/ViewType.kt` (LGPL-3.0), including its
//  `isHalfSizeableBlock` table.
//
//  Why this lives in the package rather than in a view: pairing consecutive half
//  cards into rows is the kind of logic that silently produces a ragged column,
//  and it is testable without a screen.
//

import Foundation

public enum MainCardKind: String, CaseIterable, Sendable {
    case header
    case alert
    case precipitationNowcast
    case daily
    case hourly
    case precipitation
    case wind
    case airQuality
    case pollen
    case humidity
    case uv
    case visibility
    case pressure
    case sun
    case moon
    case clock
    case footer

    /// Upstream's `isHalfSizeableBlock`: full-size cards own their row, half-size
    /// cards pair up two per row. `nil` in Kotlin for unknown types; here the enum
    /// is exhaustive, so the answer is always definite.
    public var isHalfSizeable: Bool {
        switch self {
        case .header, .alert, .precipitationNowcast, .daily, .hourly, .footer:
            return false
        case .precipitation, .wind, .airQuality, .pollen, .humidity, .uv,
             .visibility, .pressure, .sun, .moon, .clock:
            return true
        }
    }
}

/// One visual row of the main screen.
public enum MainCardRow: Equatable, Sendable {
    case full(MainCardKind)
    /// Two half-size cards side by side, in upstream's order.
    case half(MainCardKind, MainCardKind)
    /// A single half-size card alone in its row — legal, and it must occupy only
    /// half the width rather than stretching.
    case halfAlone(MainCardKind)

    public var kinds: [MainCardKind] {
        switch self {
        case .full(let kind): return [kind]
        case .half(let lhs, let rhs): return [lhs, rhs]
        case .halfAlone(let kind): return [kind]
        }
    }
}

public enum CardLayout {
    /// Groups an ordered list of cards into rows: consecutive half-size cards pair,
    /// full-size cards stand alone, and a trailing half card is marked alone.
    public static func rows(for kinds: [MainCardKind]) -> [MainCardRow] {
        var rows: [MainCardRow] = []
        var pendingHalf: MainCardKind?

        func flushPending() {
            if let pending = pendingHalf {
                rows.append(.halfAlone(pending))
                pendingHalf = nil
            }
        }

        for kind in kinds {
            if kind.isHalfSizeable {
                if let pending = pendingHalf {
                    rows.append(.half(pending, kind))
                    pendingHalf = nil
                } else {
                    pendingHalf = kind
                }
            } else {
                flushPending()
                rows.append(.full(kind))
            }
        }
        flushPending()
        return rows
    }
}
