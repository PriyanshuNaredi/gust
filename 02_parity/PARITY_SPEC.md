# Parity spec — Breezy Weather 6.2.2 → iOS, scoped

Stage 3 of the playbook. Every row cites the source file it came from
(`analysis/upstream` = `breezy-weather/breezy-weather` at tag `v6.2.2`, the exact build of the
APK whose checksum matched the official release asset). The **Proof** column gets filled as we
build; a row without a proof is not done.

Scope decision: **Option A** — main screen, details, locations, search, settings subset, one source
(Open-Meteo), English only, no alerts.

## 1. Why alerts are out (a consequence, not a preference)

Breezy's alerts come from provider APIs that publish them (NWS, MeteoAlarm, DWD, …).
Open-Meteo publishes no alerts endpoint. With one source, there is nothing to show, so
`alertList` stays an empty list in the model and the ALERT card is not built.
`app/.../ui/alert/` (4 files) and `ui/main/adapters/main/holder/AlertViewHolder.kt` are therefore
out of scope.

## 2. Screen inventory

| # | Android screen | Source | iOS plan | Proof |
|---|---|---|---|---|
| 1 | Main (forecast for one location, card list) | `ui/main/MainActivity.kt` (910 lines), `fragments/HomeFragment.kt` (526) | `MainScreen` + `CardList` | tbd |
| 2 | Locations drawer/management (list, add, remove, reorder, refresh) | `fragments/ManagementFragment.kt` (718), `adapters/location/*` | `LocationsScreen` (sheet) | tbd |
| 3 | Details (per-metric charts) | `ui/details/DetailsActivity.kt`, `DetailsScreen.kt`, `components/*` (12 files) | `DetailsScreen` with per-metric chart pages | tbd |
| 4 | Search (location search) | `ui/search/` (4 files) | `SearchScreen` | tbd |
| 5 | Settings subset | `ui/settings/` (37 files) | `SettingsScreen` (see §6) | tbd |
| — | About, Alert list, Widget configs, Live wallpaper config, Tile service, Worker info, Dependencies, Privacy | `ui/about`, `ui/alert`, `ui/settings/activities/*` | **out** | n/a |

Out-of-scope Android components, from the manifest (26 activities total): all 7 widget-config
activities, `LiveWallpaperConfigActivity`, `PreviewIconActivity`, `WorkerInfoActivity`,
`DependenciesActivity`, `PrivacyPolicyActivity`, `AlertActivity`, `SettingsActivity` (replaced by a
SwiftUI sheet).

## 3. Main-screen card catalog

From `ui/main/adapters/main/ViewType.kt` — 15 card types + header/footer. `isHalfSizeableBlock`
decides whether a card participates in the 2-column half-size grid, which is a **layout rule, not a
styling choice**:

| ViewType | Card | Size | Source holder | In scope |
|---|---|---|---|---|
| 0 | HEADER (location, temperature, condition, refresh time) | full | `HeaderViewHolder.kt` | yes |
| 1 | ALERT | full | `AlertViewHolder.kt` | **no** (no alerts from Open-Meteo) |
| 2 | PRECIPITATION_NOWCAST | full | `PrecipitationNowcastViewHolder.kt` | yes (minutely) |
| 3 | DAILY | full | `DailyViewHolder.kt` | yes |
| 4 | HOURLY | full | `HourlyViewHolder.kt` | yes |
| 5 | PRECIPITATION | half | `PrecipitationViewHolder.kt` | yes |
| 6 | WIND | half | `WindViewHolder.kt` | yes |
| 7 | AIR_QUALITY | half | `AirQualityViewHolder.kt` | yes |
| 8 | POLLEN | half | `PollenViewHolder.kt` | **no** (Open-Meteo has no pollen) |
| 9 | HUMIDITY | half | `HumidityViewHolder.kt` | yes |
| 10 | UV | half | `UvViewHolder.kt` | yes |
| 11 | VISIBILITY | half | `VisibilityViewHolder.kt` | yes |
| 12 | PRESSURE | half | `PressureViewHolder.kt` | yes |
| 13 | SUN | half | `SunViewHolder.kt` | yes |
| 14 | MOON | half | `MoonViewHolder.kt` | yes |
| 15 | CLOCK | half | `ClockViewHolder.kt` | yes (device time, trivial) |
| -1 | FOOTER (attribution/update info) | full | `FooterViewHolder.kt` | yes |

Half-size semantics to port exactly: consecutive half-size cards pair into a row; a lone half card
occupies half the width and leaves the remainder empty. `AbstractMainCardViewHolder` /
`AbstractMainViewHolder` (in `holder/`) hold the shared padding/card behaviour — read before
building the iOS card base type.

## 4. Details screens

`ui/details/components/` — 12 metric pages, each a chart plus a summary:

`DetailsAirQuality`, `DetailsCloudCover`, `DetailsCommon`, `DetailsConditions`, `DetailsHumidity`,
`DetailsPollen` (out), `DetailsPrecipitation`, `DetailsPressure`, `DetailsSunMoon`, `DetailsUV`,
`DetailsVisibility`, `DetailsWind`.

Charts are custom-drawn, not a chart library, so iOS parity means a SwiftUI `Canvas` port of the
same plot geometry — **not** Swift Charts, whose axis/inset behaviour would change every plot.

## 5. Data model (`domain/src/main/kotlin/breezyweather/domain/weather/model/`)

```
Weather(base, current, dailyForecast[], hourlyForecast[], minutelyForecast[], alertList[], normals{})
Current(weatherText, weatherCode, temperature, wind, uV, airQuality, relativeHumidity, dewPoint,
        pressure, cloudCover, visibility, ceiling, dailyForecast: String?, hourlyForecast: String?)
```

Derived properties that the UI relies on and that must be ported deliberately rather than
recomputed ad hoc: `nextHourlyForecast`, `fullNextHourlyForecast`, `todayIndex`, `today`,
`tomorrow`, `dailyForecastStartingToday`, `currentAlertList`, `minutelyForecastBy5Minutes`,
`hourlyAirQuality`, `dailyAirQuality`, `currentAirQuality`, `dailyPollen`.

Units are their own module (`weather-unit/`, 35 files) — `Temperature`, `Speed`, `Pressure`,
`Distance`, `Duration`, `Ratio`, `Precipitation`, `PollutantConcentration`, `PollenConcentration`,
each with a unit enum, a value type with conversion, formatting and decimal rules
(`formatting/MeasureUnitFormatting.kt`, `UnitDecimals.kt`, `NumberFormatting.kt`).

**Correction (found while porting):** this module is *not* pure logic. It imports
`android.content.Context`, `android.icu.util.MeasureUnit`, `androidx.annotation.RequiresApi`,
`java.util.Locale` and the module's own `R` string table — the arithmetic is portable, the
formatting is Android plumbing. The port therefore splits it: conversions and computing port 1:1
(and carry upstream's numeric test expectations), while formatting is reimplemented behind our own
protocol. `05_ios/BreezyUnits/` is that split, slice 1.

## 6. Settings subset

In: unit preferences (temperature/speed/distance/pressure/precipitation), number formatting,
theme (light/dark/auto), language (English only), main-screen card visibility/order if cheap,
data source = Open-Meteo (fixed), about/licence text.
Out: source management, notification/alerts settings, widget settings, icon packs, custom
display/layout overrides, screen reader-specific overrides, Gadgetbridge sharing, background
refresh cadence.

## 7. Network

| Endpoint | Source | Notes |
|---|---|---|
| Open-Meteo forecast | `sources/openmeteo/OpenMeteoForecastApi.kt` | `current`, `hourly`, `daily` are comma-joined variable lists; `timezone`, `latitude`, `longitude`; a `models` enum (`best_match`, `ecmwf_ifs`, `gfs_*`, `jma_*`, `kma_*`, `icon_*`, …) |
| Open-Meteo geocoding | `sources/openmeteo/json/OpenMeteoLocationResults.kt` | location search (shared with the upstream code path) |

Refresh policy must be copied from `background/` (out of scope for *implementation*, but the
foreground refresh interval and cache staleness rules are in scope — read the constants before
inventing a number).

## 8. Deviation ledger (the cut list)

| # | Android behaviour | iOS build | Why |
|---|---|---|---|
| 1 | 53 weather sources | Open-Meteo only | 1,097 classes; each source is its own API, mapping and error model |
| 2 | Live wallpaper | none | no iOS equivalent |
| 3 | 7 home-screen widgets (RemoteViews) | none | WidgetKit is a different product, not a port |
| 4 | Alerts | none | no alerts endpoint in Open-Meteo |
| 5 | Pollen card | none | not available from the chosen source |
| 6 | 100 locales | English only | copy is parity; 100 locales of new translations is a separate project |
| 7 | Background refresh w/ boot receiver, alarms, foreground service | resume-time refresh + `.refreshable` | iOS gives no such guarantees |
| 8 | Custom icon packs from other apps | fixed app icon (rendered from the APK vector) | cross-app asset loading has no iOS equivalent |
| 9 | Content provider / Gadgetbridge sharing | none | no cross-app data model |
| 10 | Status-bar tile, notification stack | none | out of scope per Option A |

## 9. Open questions to settle before stage 6

1. Location selection: current-location only, or current + saved cities? (Android: both, with
   separate current-location entry — confirm in `ManagementFragment` before building.)
2. Card configuration (show/hide/reorder) — the Android app lets users manage card order
   (`CardDisplayManageActivity`). In or out for v1?
3. Details charts: which 3–4 metrics ship first (all 11 is a lot of Canvas work).
4. Minutely (nowcast) — Open-Meteo provides it for some regions only; behaviour when absent?

## 10. Licence

LGPL-3.0 (`analysis/upstream/LICENSE`), plus `LICENSE_ADDITIONAL` (trademark/no-misrepresentation
clauses). The iOS port therefore ships LGPL-3.0 with its source, keeps upstream notices, and must be
marked as a modified/derived version rather than passed off as Breezy Weather itself. The name
"Breezy Weather" and its logo are not ours to use as the port's identity.
