# Breezy Weather 6.2.2 — scope reality check

Written after `05_tools/apk-recon.sh` (apk-to-ipa-playbook) on
`breezy-weather-v6.2.2_standard.apk`. Every number below is from `recon/`.

## What this APK is

| Fact | Value |
|---|---|
| Package / version | `org.breezyweather` 6.2.2 (code 60202) |
| SHA-256 | `20a33a58…c6309` — **matches the official v6.2.2 "Standard / Universal" release asset** |
| Size | 21.8 MB universal |
| Signature | self-signed, upstream release key |
| Licence | **LGPL-3.0** (repo metadata; the repo also ships a `LICENSE_ADDITIONAL`) — not MIT |
| Upstream | `breezy-weather/breezy-weather`, 6,192 commits, multi-module (app/data/domain/work/ui-weather-view/weather-unit/maps-utils) |

**Licence consequence, stated plainly:** a Swift port is a derivative work, so it must be released
under LGPL-3.0 with source available and notices kept. That is a different obligation from the
MIT Weather port and it rules out a closed or purely private release if published. Confirm with the
upstream `LICENSE` and `LICENSE_ADDITIONAL` before publishing anything.

## Measured shape

| Measure | Breezy 6.2.2 | (Weather 1.1.1, for scale) |
|---|---|---|
| App classes (decompiled) | **1,204** | 43 |
| App lines (decompiled Java) | ~178,000 | 18,450 |
| Activities | **26** | 1 |
| Services / receivers / providers | 6 / 19 / 4 | 0 / 1 / 1 |
| Locales | **100** | 1 |
| Network sources (weather providers) | **53** | 1 (Open-Meteo) |

Where the code lives — this is the decisive number:

```
org.breezyweather.sources      1,097 classes   ← 53 provider integrations (91% of the app)
org.breezyweather.background      40
org.breezyweather.ui              35
org.breezyweather.remoteviews     24
org.breezyweather.wallpaper        3
```

UI stack is hybrid, not Compose-only: `RecyclerView` in 10 UI classes, `ComposeView` in 2, Hilt DI
in 32. Lists are View-system, so stage 6 is partly `UIViewRepresentable`, not just SwiftUI.

## Features with no iOS equivalent (measured from the manifest and app classes)

| Android feature | Evidence | iOS reality |
|---|---|---|
| Live wallpaper | `MaterialLiveWallpaperService`, `wallpaper/*` | **No equivalent.** Cannot port. |
| Home-screen widgets ×7 config activities | `remoteviews/*` (24 classes), 26 `AppWidgetProvider` refs | WidgetKit is a different product — a rewrite, not a port |
| Background refresh + boot receiver + alarms | `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `RECEIVE_BOOT_COMPLETED`, `AlarmManager` | `BGTaskScheduler` is opportunistic; cannot promise the same cadence |
| Background location | `ACCESS_BACKGROUND_LOCATION` | "Always" authorisation is a separate, reviewable request |
| Status bar / tile service | `Hilt_TileService`, `EXPAND_STATUS_BAR` | No equivalent |
| Data sharing with other apps | `WeatherContentProvider`, Gadgetbridge integration | No content-provider model |
| Custom icon packs from other apps | icon-pack loading | Not portable as-is |
| Battery-optimisation exemption | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Not applicable |

## The honest sizing

The Weather port was 2,144 Kotlin lines → 6,079 Swift lines in six sittings, with full parity.
Breezy is **~80× larger by class count**, with 26 activities, 100 locales, 53 network providers,
plus several features that cannot exist on iOS at all.

A full-parity port is a multi-month project, and three of its headline features (live wallpaper,
widgets, background cadence) are not portable by design. Anyone who says otherwise has not counted.

## Options

**A — Scoped port (recommended).** Main screen, details, locations, search, a settings subset.
One weather source (Open-Meteo, which Breezy itself ships and which needs no key). No widgets, no
wallpaper, no alerts, no background refresh, no icon packs. English only.
→ Reaches something genuinely usable and Breezy-shaped, ~6,000–9,000 Swift lines, comparable to
8–12 sessions of the Weather port. LGPL-3.0.

**B — Main screen only.** Saved locations, current conditions, hourly/daily, one source.
→ ~2,500–3,500 Swift lines, 3–5 sessions. A proof of parity, not an app.

**C — Full parity.** Everything above plus 53 providers, 100 locales, alerts, widgets (rewritten in
WidgetKit), notification stack.
→ Not feasible in this collaboration; realistically months of work and several iOS-impossible items.

**D — Don't port; reimplement the design.** A native app that borrows Breezy's information design
without its code or copy. → Legally cleaner (no LGPL obligation), but it is a new product, not a port,
and the parity question disappears.

## If A is chosen, the cut list must be explicit before any code

1. Which screens (main / details / locations / search / settings-subset).
2. Which single source, and whether "add source" is offered at all.
3. Alerts: in or out.
4. Auto dark mode: in (cheap) or out.
5. Locales: English only, or English + device locale formatting.
6. Charts in the details screen: Swift Charts, or a custom `Canvas` port.

Each of those is a stage-3 parity-spec row, and each one omitted is a row in the deviation ledger.