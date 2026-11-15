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

## Deviations added by the card-stack slice

| # | Deviation | Reason | Reversible? |
|---|---|---|---|
| 11 | The nowcast strip charts three hours, not upstream's entire minutely series (17 days for Open-Meteo) | A 17-day strip in a 341 pt card is 0.2 pt per bar; it cannot be read. Three hours answers "is it about to rain". | Yes — change `window(maxSteps:)` |
| 12 | When rain is later than the window head, the strip starts one step before the first wet step and the label says "from HH:MM" | Upstream's full-series chart always contains the rain. A fixed short window would otherwise read "rain starting" over an empty strip, which is what this port did before the fix. | Yes |
| 13 | The precipitation card shows one "today" total; upstream splits day/night and looks at the previous night | Day/night halves need sunrise/sunset, which is the astronomy slice | Yes, once astronomy lands |

Ported exactly, for the record: the y-scale is **absolute** (bottom at "heavy", 15 mm/h), not
normalised to the window's peak — a drizzle must stay small, as it does on Android. Thresholds are
per hour, so a 15-minute accumulation is multiplied by 3600/900 before comparison.

## Deviations added by the astronomy and app-shell slices

| # | Deviation | Reason | Reversible? |
|---|---|---|---|
| 14 | Daily request appends `sunrise,sunset` (23 daily variables, upstream sends 21) | Upstream never asks for them, so Breezy's sun card is empty with Open-Meteo. Real times beat a hand-rolled solar algorithm. | Yes — drop two variables |
| 15 | Moon phase computed locally; no moonrise/moonset | Open-Meteo serves no moon data. A mean-synodic model is good to a few hours: fine for illumination, useless for a rise time. | Yes, with a real ephemeris |
| 16 | Saved places persist to `Application Support/Gust/places.json`; preferences to `UserDefaults` | Upstream uses Room; a JSON file and one defaults key are the honest minimum for a port this size. | Yes |
| 17 | Place search uses Open-Meteo geocoding | Upstream uses Android's `Geocoder` or a bundled city list. The geocoding service needs no key and carries IANA zones. | Yes |
| 18 | Detail pages show one series per metric card | Upstream's detail screens are per-element pages with sliders and comparisons between locations. This port keeps the chart and the values, drops the comparisons. | Yes |

Ported exactly in these slices: the eight-name moon-phase vocabulary, the
`max(O3, NO2, PM10, PM25)` index rule, Beaufort integer bands, the location's time zone applied to
every displayed time, and the LGPL/notice obligations (bundled, reachable in Settings).

## Deviation 19: pollen only inside CAMS's European domain

Upstream gates pollen on `COPERNICUS_POLLEN_BBOX` (25° W–45° E, 30° N–72° N) and so does this
port, for the same reason: outside that box the variables come back empty, and an empty pollen card
reads as "no pollen" when the truth is "not covered". The card says "no coverage here" instead, and
a test pins the box corners.

## Deviations added by the card, settings and detail slices

| # | Deviation | Reason | Reversible? |
|---|---|---|---|
| 20 | Card subtitles omitted on hourly/daily | The subtitle text is `current.hourlyForecast` / `current.dailyForecast`, a sentence only some providers send. Open-Meteo sends none, so upstream shows no subtitle with this source either. | Yes, with a provider that sends it |
| 21 | Detail pages omit deviation-from-normal, the "Normal" reference lines and degree days | All three need a 30-year climatology. A fabricated baseline would be worse than their absence. | Yes, with a climate data set |
| 22 | Main screen hides Notifications and External modules rows entirely | No iOS equivalent in this port (see SCOPE.md). An empty screen implying the feature exists would be dishonest. | No |
| 23 | Day/night split for precipitation uses upstream's fixed 05:00/17:00 boundary, not sunrise/sunset | That is what upstream does; matching it keeps the card and the detail panel consistent. | Yes |
| 24 | App bar uses a material blur, not the weather colour | Upstream paints the bar in the weather colour. SwiftUI ignores a `toolbarBackground` colour that is derived from data loaded after the bar is built, so the bar cannot follow the forecast on iOS 17. | Yes, on iOS 18 with `toolbarBackgroundVisibility` and a bar colour resolved before first paint |

## The visual layer, taken from the layouts rather than approximated

The first pass rendered Material-*ish* cards: rounded rectangles everywhere, iOS tab bar, SF
Symbols for weather, one row per forecast day. It was wrong in every one of those four places, and
the layouts say so:

| Thing | Where upstream decides it | What the port now does |
|---|---|---|
| Card corner | `res/layout/container_main_*.xml`, `app:shapeAppearance` | Two shapes only: `Corner.ExtraLarge` (28dp) for header-adjacent blocks, `Corner.Full` (a circle) for air quality, pressure, visibility and wind. Everything else in between was invented. |
| Half-size cell height | `dimensionRatio="1:1"` on the circular containers | Each half card is framed to a square, so a rect card and a circle beside it stand the same height. |
| Big number | `styles.xml` `Weather.TextAppearance.MainBlock.NumberDigit` | 45pt number with the unit as a separate 20pt label beside it — never in the same string. |
| Card title | `title_icon` + `title`, `textAppearanceLabelLarge`, `colorSurfaceInverse` | 16pt bold sentence-case title with a 15pt icon to its left. |
| Weather artwork | `Constants.getResourcesName(code) + "_" + day|night` resolved through `res/xml/icon_provider_drawable_filter.xml` | The 85 `weather_*.png` files ship unchanged; `WeatherIcons` reproduces the filter (only `clear` and `partly_cloudy` split day/night) and a test asserts every produced name has a file. |
| Daily block | `DailyViewHolder` + `trend_item_width` 67dp | A horizontally scrolling strip of 67pt columns (weekday, date, icon, high, low) over a shared trend chart, with the Conditions / Air quality / Wind tabs. Not a list of rows. |
| Sun and moon | `DetailsSunMoon` | A dashed semicircle with the body marker at its current position, rise/set under each end. |
| Navigation | `activity_main.xml`: up-button + edit + open-in-another-app; no bottom navigation | No tab bar. The place list is behind the top-left button, settings and licences behind the overflow. `AppFlowTests` asserts `app.tabBars.count == 0`. |

Two things the port cannot copy, and does not pretend to: the app bar in upstream is tinted with the
weather colour, and SwiftUI will not take a colour that arrives after the bar is built (`toolbarBackground`
with a value derived from the loaded forecast renders as the system default), so the bar is a material
blur over the same backdrop; and the header has no weather artwork upstream, so the port's header has
none either.

## The background: an asset and a scene, both ported by the numbers

The first version of the backdrop was three blurred white circles over a hand-mixed
gradient. Upstream has neither: `WeatherImplementorFactory.getBackgroundId` picks one of
twelve `weather_background_*.xml` gradient assets by (weather kind, daylight) and the
`-night` resource qualifier overrides eleven of them for dark theme; a `MaterialWeatherView`
then animates a geometric scene over it.

Both halves are now data in `BreezyUnits.WeatherScene`, asserted in
`WeatherSceneTests`:

| What | Ported value |
|---|---|
| Gradients | All 12 assets plus 11 `-night` overrides, three stops each, angle 270, colours pinned hex by hex in a test |
| Clear day | Three rotating square layers, 8 rays each, alphas 0.16 / 0.08 / 0.04, quarter turns of 3 / 4 / 5 s, centred at (width, 0.5 × width) |
| Cloud / cloudy / fog / haze / thunder | The implementors' circle tables: 6 circles for `cloud` (alphas 0.40/0.10), 6 for `cloudy`/`thunder`, 9 for `fog`/`haze` (alpha 0.3), each with its own breathe period and 1.1–1.2 peak scale |
| Rain / sleet / thunderstorm | 75 streaks (45 for sleet), three colour bands, 8° tilt, widths 0.002–0.003 of the diagonal (0.004–0.006 for sleet), heights 6–10× |
| Snow | 50 circles, radii 0.005–0.012 of the diagonal, three bands |
| Hail | 51 taller streaks, 10° tilt |
| Wind | 160 thin gusts, three green bands |
| Night | 50 stars (cloud kinds) / 70 (clear), ten-colour palette, fade in and out over 2.5–5 s |
| Clear night | Ten meteors at 60°, reviving every 5–25 s |
| Thunder | Violet flash (81, 67, 168) at 0.66 alpha, twice per cycle |

Two deviations, both deliberate:

| # | Deviation | Reason |
|---|---|---|
| 25 | The scene does not parallax with device tilt | Upstream feeds accelerometer rotation into every particle. Reading it needs `CoreMotion` and a motion-permission story for a background; the intrinsic motion (breathe, fall, twinkle) is what a user sees when holding the phone still |
| 26 | The scene runs at 20 fps, not the display rate | Measured idle CPU on the main screen: ~10% at 30 fps, ~5.5% at 20 fps, ~0.3% paused. The scene is slow enough that 60 fps buys nothing visible. `Appearance → Animated background` pauses it entirely |

## The nowcast: five-minute buckets over a two-hour window

`PrecipitationNowcastViewHolder` is a Vico column chart, which is to say: a `Canvas` with
rules. Ported from it, and asserted in `NowcastChartTests`:

| What | Ported value |
|---|---|
| Bucket | 5 minutes, whatever the source interval is |
| Span | 2 hours = 24 buckets (DEVIATION 27) |
| Y scale | `max(15 mm/h, wettest bucket)` — absolute, never normalised |
| Thresholds | 5 / 10 / 15 mm/h; below 30 mm/h all three labels, at or below 15 mm/h the medium one returns, above 30 mm/h only heavy survives |
| Axis | baseline plus three labels: start, half, end (end = last bucket **plus one bucket**, as upstream's `maxX` is the last step's ending date) |
| Bar colour | `RainImplementor.getThemeColor(TYPE_RAIN, daylight)` = `#4297E7` by day, `#6B91CF` at night (`getBrighterColor`: saturation −0.25, value +0.25) |
| Axis / label colour | `colorTextGrey` `#4D4D4D` light, `colorTextGrey2nd` `#B2B2B2` dark |
| Title | "Precipitation soon" / "Precipitation" / "Precipitation stopping soon" |
| Description | "Expected to start at …" / "Expected to continue until at least …" / "Expected to stop at …" / "No precipitation" |

Two defects that only appeared once it was drawn:

- **The chart began at midnight.** Open-Meteo's `minutely_15` series starts at local
  midnight and runs for days; upstream's radar providers send two hours starting now.
  Applying the title law to the whole series produced "Expected to start at 2:15 AM" over
  a chart of 17:30–19:30. The series is now clipped to the charted span, which also
  guarantees the sentence and the chart describe the same two hours.
- **The heavy label was clipped.** It is drawn above its line, and the heavy line is at
  the top of the plot. The label now flips below its line when the line is within 14 pt
  of the top.

| # | Deviation | Reason |
|---|---|---|
| 27 | Two-hour window, not the whole minutely series | Days of 15-minute steps would be one bucket per pixel |
| 28 | The description sits above the chart instead of overlapping its top-left corner | Upstream's constraint puts `nowcasting_block_subtitle` on the chart's first row; at 14 pt over a bar chart the text is lost against the bars |
| 29 | No drag marker (the "14:20–14:25: Light" bubble) | Upstream shows a `DefaultCartesianMarker` on touch. Worth doing, but it is an interaction, not a repaint: recorded here so it is not mistaken for done |

## The precipitation block: two clocks, not one

`PrecipitationViewHolder` decides *which half of the day* to describe with one pair of
hours and sums the hours into that half with another:

| Decision | Hours | Source |
|---|---|---|
| Which half is shown | 05:00–16:59 = day, everything else = night | `PrecipitationViewHolder.onBindView` |
| Which hours are summed | 06:00–17:59 = day, 18:00–05:59 = night | `CommonConverter.getHourlyListByHalfDay` (it shifts each hour by six hours and calls anything before noon "day") |

They disagree between 05:00–05:59 and 17:00–17:59. That is upstream's behaviour, and this
port reproduces it rather than tidying it up.

The port's own bug: it used the 05/17 split for *both* jobs, and resolved the night window
forwards. At 03:00 it summed 17:00→05:00 of the day that was just beginning — hours that
had not happened — found nothing, and rendered "—". The night window now belongs to the
evening it starts in, so 03:00 shows the night that ended.

| What | Ported value |
|---|---|
| Label | "Daytime rain" / "Nighttime snow" / "… precipitation"; rain and snow both present → "precipitation"; one of them present and equal to the total → its own word; equal to *less* than the total → "precipitation" (upstream compares with `==`) |
| Value | The summed total of that half; upstream shows `-` when the source has no total for it |
| Unit split | The value is formatted through the normal precipitation unit, so inches work |

The rule worth copying: **when one card reads two different splits of the same data, port
both of them.** Collapsing them to one makes the card disagree with the original for two
hours a day, and only for two hours a day, which is the kind of difference a screenshot
comparison taken at noon will never show.
