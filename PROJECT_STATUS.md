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
| 3 | Parity spec | **signed off** (Option A + defaults) | `02_parity/PARITY_SPEC.md` |
| 4 | Scaffolding | **done** — app builds, installs, launches, links the package; UI gate green | `05_ios/Gust/`, `07_logs/shots/shell-launch.png` |
| 5 | Data layer | **slices 1–4 done**: units, Open-Meteo request/response/mapping/client | 27 tests, 0 failures |
| 6 | UI port | not started | — |
| 7 | Custom rendering (charts) | not started | — |
| 8 | Verification | not started | — |
| 9 | Release (unsigned IPA) | not started | — |

## Confirmed scope defaults (2026-11-15)

Saved cities in, card order fixed for v1, first detail charts = Conditions + Precipitation + Wind,
minutely hidden when the source has no data.

## Slice log

| Slice | What | Proof |
|---|---|---|
| 1 | `BreezyUnits`: reference-unit storage, Temperature (4 units), Precipitation (5 units), `computeTotalPrecipitation`, `snowToLiquidRatio`, `computeHumidex` | `swift test` → 10 passed, assertions lifted from upstream's own `weather-unit` tests |
| 2 | Speed (7 units incl. Beaufort boundaries), Distance (5), Pressure (7), Ratio (3), `computeApparentTemperature`, `computeWindChillTemperature`, `computeTotalProbabilityOfPrecipitation` | `swift test` → 20 passed |
| 3 | App shell `Gust` (XcodeGen), links `BreezyUnits`, renders ported values, 2 UI tests | `./07_tools/macos-tests.sh all` → logic 20 + ui 2, 0 failures; screenshot `07_logs/shots/shell-launch.png` |

| 4 | Open-Meteo layer: request built with upstream's exact variable lists and order, response types keyed by upstream's `@SerialName`, mapping to domain types, URLSession client that treats a 200-with-error body as failure | `swift test` → 27 passed, against a **recorded real payload** (Berlin, committed fixture) |
| 5 | Live data in the app: `ContentView` fetches Berlin on `.task` and renders it through the ported units | `screenshots/live-openmeteo.png` → 1.6 °C, 10.0 km/h, 88 %, 1017.5 hPa |

Shell values are not placeholders: humidex 31.0 °C at 25 °C / 18 °C dew point, apparent 24.1 °C,
pressure 1013.25 hPa, and wind chill correctly absent above 10 °C. Two XcodeGen traps found and
fixed: `CFBundleVersion` missing (build succeeded, install refused with code 22) and a stale
project silently excluding new files.

`Duration` is deferred: upstream's is 322 lines of humanised multi-unit output ("2 h 15 min") built
on Android's `MeasureUnit`, so it belongs with the formatting layer, not the arithmetic.

## Bugs found in my own tooling (worth keeping)

| Bug | Symptom | Fix |
|---|---|---|
| build script piped `xcodebuild` into `grep` | `BUILD FAILED` still printed `OK` and installed the **previous** app; the screenshot showed the old shell | capture the log, branch on exit status, then grep for humans |
| `simctl launch` on a running app | pid unchanged, screenshot showed stale UI twice in a row | terminate + uninstall + install + launch when verifying a new build |

## Open decisions

See `02_parity/PARITY_SPEC.md` §9 — location model, card configuration, which detail charts ship
first, minutely-when-absent behaviour.

## What is already known to be hard

1. **Charts.** 12 custom-drawn detail pages; `Canvas` port, not Swift Charts.
2. **The card system.** 15 card types with a half/full two-column rule and user reordering.
3. **Units.** A whole module ports 1:1, but it is 35 files with formatting edge cases
   (numeral systems, decimals, separators) — the largest *cheap* win if done first.
4. **Copy.** English-only still means several hundred strings; they come from `strings.xml`.
