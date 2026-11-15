# Gust

An iOS port of [Breezy Weather](https://github.com/breezy-weather/breezy-weather) 6.2.2,
built by reading the upstream Kotlin rather than guessing at behaviour.

**Not affiliated with Breezy Weather.** The name "Gust" is deliberate: upstream's
`LICENSE_ADDITIONAL` prohibits misrepresenting the origin of the software, so this port
ships under its own name, its own icon, and ships LGPL-3.0 with the upstream notices.

| | |
|---|---|
| Source APK | `breezy-weather-v6.2.2_standard.apk`, SHA-256 `20a33a588e884257ab9329fee794d30a9d15ea067f64302c70c69c9adc3c6309` |
| Upstream tag | `v6.2.2` |
| Scope | Option A — see `SCOPE.md` |
| Weather source | Open-Meteo (forecast + air quality + geocoding) |
| Platform | iOS 17+, Swift 6 toolchain, Swift 5 language mode |
| Tests | 96 package + 10 UI, all green |
| Licence | LGPL-3.0, plus upstream's additional terms |

## What it does

- **Main screen** — upstream's weather-coloured backdrop and header, then the card stack
  with its half/full layout rule: 15-minute nowcast (Canvas), daily and hourly cards with
  Conditions / Air quality / Wind tabs, then precipitation (day or night, named after what
  is in it), wind with a direction arrow, air quality as a ring, pollen with upstream's
  per-type severity, humidity, UV, visibility, pressure, sun, moon, local time and the
  attribution footer.
- **Detail pages** — a date selector, a Daytime/Nighttime panel, a category menu, and
  charts drawn with `Canvas`: hourly (temperature over precipitation probability), daily
  range bars, one series per metric card, four pollutant lines for air quality.
- **Locations** — saved places with search over Open-Meteo geocoding, selection and
  removal, persisted between launches.
- **Settings** — temperature, wind, pressure, precipitation and distance units, all
  wired to live formatting; licence and notice texts in-app.

## Build

```bash
./07_tools/macos-build.sh --run      # build + install + launch on a simulator
./07_tools/macos-tests.sh all        # package tests, then UI tests
./07_tools/ipa-build.sh 0.1.0        # unsigned IPA for SideStore/LiveContainer
```

Requires Xcode with the iOS 17 SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). No Apple ID, team or provisioning profile is used anywhere:
both the simulator build and the IPA are unsigned by design.

## How it was built

The method, the evidence and the defects found along the way live in a companion
repository, `apk-to-ipa-playbook`. The short version:

1. Recon the APK, pin its checksum, and count *app* classes rather than library classes.
2. Read the upstream Kotlin at the matching tag; jadx output loses idioms and renames
   packages.
3. Port the arithmetic into a Swift package with the upstream's own test expectations.
4. Port the UI only after the data layer can be tested in milliseconds.
5. Verify with screenshots and measured layout, not with "it looks right".

## Deviations from upstream

Recorded in `02_parity/PARITY_SPEC.md`; the ones a user can see:

- Main screen shows a subset of upstream's 15 cards (no alerts, pollen or clock-only
  views — see `SCOPE.md` for the reason each one is out).
- Sun times come from Open-Meteo's own `sunrise`/`sunset` variables, which upstream never
  requests, so Breezy's sun card is empty when the source is Open-Meteo.
- Moon phase is computed locally; there is no moonrise/moonset.
- The nowcast strip charts three hours, not upstream's entire minutely series.
- The precipitation card shows one daily total rather than upstream's day/night split.

## Layout

```
02_parity/    screen inventory, card catalog, deviation ledger
03_.../       (scope and analysis notes)
05_ios/
  BreezyUnits/  portable logic: units, Open-Meteo, AQI, nowcast, layout, preferences
  Gust/         the app: screens, cards, stores
06_release/     unsigned IPA output
07_tools/       build, test and packaging scripts
07_logs/        screenshots and build logs (not tracked)
```
