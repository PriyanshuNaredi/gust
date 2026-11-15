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
| 5 | Data layer | **done**: units, Open-Meteo request/response/mapping/client, hourly/daily/minutely models | 40 logic tests, 0 failures |
| 6 | Main screen | **done**: header, nowcast, daily, hourly, 10 half/full cards, footer | UI tests green |
| 7 | Detail pages | **done**: hourly, daily, per-metric series, air quality (Canvas) | UI tests green |
| 8 | Locations + search | **done**: saved places, geocoding search, persistence | 10 UI tests green |
| 9 | Settings | **done**: five unit pickers wired to live formatting, licences screen | UI tests green |
| 10 | Release | **done**: unsigned IPA + CI workflow | `ipa-build.sh` verifies bundle, version keys, licences, platform |
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

## Parity rules ported in the card-stack slice

| Rule | Upstream source | Why a plausible port gets it wrong |
|---|---|---|
| Daily list drops the last day (`0 until size - 1`) | `OpenMeteoService.getDailyList` | The payload has 17 days; rendering 17 shows one more day than Android. My own test asserted 17 and had to change. |
| Daily date = add 1 h, then zero the hour | same | A naive `startOfDay` lands on the wrong day across a DST boundary. |
| `rain` = rain + showers | same | Keeping them apart renders a rain card that looks dry during a shower. |
| `snowfall` is centimetres, everything else millimetres | response `*_units` | Silent 10× error in snow depth. |
| Nowcast keeps one entry per step, nullable | `Minutely.precipitationIntensity` | `compactMap` slid the series 19 steps earlier (1632 → 1613). |
| WMO 4, 50 and anything unmapped → no icon | `getWeatherCode` | Inventing a family for an unknown code shows the wrong weather. |
| Half cards pair two per row; full cards own a row | `ViewType.isHalfSizeableBlock` | `LazyVGrid` stretches rows level; upstream rows are ragged. |
| AQI = max over O3, NO2, PM10, PM25 only | `AirQuality.getIndex` | Maxing all six is right most days and wrong when CO or SO2 is extreme. |
| AQI keeps going linearly above the last breakpoint | `PollutantIndex.getIndex` | A clamp looks safer and diverges on polluted days. |
| Air quality is a separate host, 7 days, no models / no windspeed_unit | `OpenMeteoAirQualityApi` | Copying the forecast request returns nothing. |

## Deviations added by the card-stack slice

11. Nowcast charts three hours, not upstream's whole series (17 days at 0.2 pt/bar is unreadable).
12. The window moves to the first wet step and says "from HH:MM", so the title and the picture agree.
13. Precipitation card shows one "today" total; day/night halves wait for the astronomy slice.

Ported exactly: absolute y-scale to the heavy threshold (never normalised), per-hour intensity from
15-minute accumulation, and the three-case nowcast law from the first and last step only.

## Bugs found in my own tooling (worth keeping)

| Bug | Symptom | Fix |
|---|---|---|
| build script piped `xcodebuild` into `grep` | `BUILD FAILED` still printed `OK` and installed the **previous** app; the screenshot showed the old shell | capture the log, branch on exit status, then grep for humans |
| `simctl launch` on a running app | pid unchanged, screenshot showed stale UI twice in a row | terminate + uninstall + install + launch when verifying a new build |
| `grep … && { exit 1; }` under `set -e` | tests passed silently with no output at all | use `if grep …; then` |
| `out=$(failing cmd)` under `set -e` | failing UI run printed nothing, exit 65 only | capture `rc=$?` explicitly, then report |
| Title derived from the whole series, chart drawn from a fixed window | "Rain starting" over an empty strip | move the window, label it, and unit-test that a non-`.none` state always has a wet bar |
| container `.accessibilityIdentifier` | UI test waited 30 s for a label that existed, because every descendant had been renamed | `.accessibilityElement(children: .contain)` first; when a query fails, dump `app.debugDescription` before editing assertions |

## Open decisions

See `02_parity/PARITY_SPEC.md` §9 — location model, card configuration, which detail charts ship
first, minutely-when-absent behaviour.

## What is already known to be hard

1. **Charts.** 12 custom-drawn detail pages; `Canvas` port, not Swift Charts.
2. **The card system.** 15 card types with a half/full two-column rule and user reordering.
3. **Units.** A whole module ports 1:1, but it is 35 files with formatting edge cases
   (numeral systems, decimals, separators) — the largest *cheap* win if done first.
4. **Copy.** English-only still means several hundred strings; they come from `strings.xml`.
