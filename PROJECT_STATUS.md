# Breezy Weather → iOS: project status

Scoped port of Breezy Weather 6.2.2 (LGPL-3.0) to SwiftUI. Read `SCOPE.md` for why this is a
subset and `02_parity/PARITY_SPEC.md` for what exactly.

| Field | Value |
|---|---|
| Source artifact | `breezy-weather-v6.2.2_standard.apk`, SHA-256 `20a33a58…c6309` (official release asset) |
| Source code | `breezy-weather/breezy-weather` tag `v6.2.2` (`analysis/upstream`, gitignored) |
| Licence of the port | LGPL-3.0 + upstream notices |
| Scope | Option A: main, details, locations, search, settings subset; Open-Meteo; English |

## Stages

| # | Stage | State | Evidence |
|---|---|---|---|
| 1 | Recon | **done** | `recon/RECON.md` + 9 files |
| 2 | Source recovery | **done** | upstream at tag `v6.2.2` + `recon/` for the binary's own facts |
| 3 | Parity spec | **draft, needs sign-off** | `02_parity/PARITY_SPEC.md` |
| 4 | Scaffolding | not started | — |
| 5 | Data layer | not started | — |
| 6 | UI port | not started | — |
| 7 | Custom rendering (charts) | not started | — |
| 8 | Verification | not started | — |
| 9 | Release (unsigned IPA) | not started | — |

## Open decisions

See `02_parity/PARITY_SPEC.md` §9 — location model, card configuration, which detail charts ship
first, minutely-when-absent behaviour.

## What is already known to be hard

1. **Charts.** 12 custom-drawn detail pages; `Canvas` port, not Swift Charts.
2. **The card system.** 15 card types with a half/full two-column rule and user reordering.
3. **Units.** A whole module ports 1:1, but it is 35 files with formatting edge cases
   (numeral systems, decimals, separators) — the largest *cheap* win if done first.
4. **Copy.** English-only still means several hundred strings; they come from `strings.xml`.
