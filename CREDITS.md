# Credits

## Upstream

**Breezy Weather 6.2.2** — <https://github.com/breezy-weather/breezy-weather>
Copyright the Breezy Weather contributors. Licensed under the GNU Lesser General Public
License v3.0, with additional terms in `LICENSE_ADDITIONAL` (no misrepresentation of
origin, no trademark grant). This port keeps those terms: see the in-app Licences screen
and `05_ios/Gust/Resources/Licences/`.

What was ported from upstream, file by file:

| Gust file | Upstream source |
|---|---|
| `BreezyUnits/Temperature.swift`, `Speed.swift`, `Pressure.swift`, `Precipitation.swift`, `Distance.swift`, `Ratio.swift`, `TemperatureComputing.swift` | `weather-unit/` |
| `BreezyUnits/OpenMeteo*.swift` | `sources/openmeteo/` |
| `BreezyUnits/PollutantIndex.swift`, `AirQuality.swift` | `domain/weather/index/`, `domain/weather/model/AirQuality.kt` |
| `BreezyUnits/CardLayout.swift` | `ui/main/adapters/main/ViewType.kt` |
| `BreezyUnits/Nowcast.swift` | `domain/weather/model/Weather.kt` (`getMinutelyTitle`, cases) |
| `BreezyUnits/UnitPreferences.swift` | settings structure in `domain/.../SettingsManager.kt` |
| App screens and cards | `ui/main/adapters/main/holder/*`, `ui/details/` |
| `CardChrome.swift` (shapes, type scale, card chrome) | `res/layout/container_main_*.xml`, `res/values/dimens.xml`, `res/values/styles.xml` |
| `WeatherIcons.swift` | `Constants.getResourcesName()`, `res/xml/icon_provider_drawable_filter.xml` |
| `Resources/WeatherIcons/*.png` | `app/src/main/res/drawable/weather_*.png` (unmodified) |
| `ForecastScreen` navigation (no tab bar) | `res/menu/activity_main.xml` + `MainActivity` |

## Artwork

The weather illustrations in `05_ios/Gust/Resources/WeatherIcons/` (85 PNG files,
`weather_*.png`) are copied **unmodified** from upstream's
`app/src/main/res/drawable/` at tag `v6.2.2`, and are redistributed under the same
LGPL-3.0 terms as the code they came with. 83 distinct conditions, of which only `clear`
and `partly_cloudy` have separate day and night files.

What *was* rewritten is the lookup that picks one: `BreezyUnits/WeatherIcons.swift`
reproduces upstream's `Constants.getResourcesName() + "_" + day|night` naming and the
fallbacks in `res/xml/icon_provider_drawable_filter.xml`. A test asserts that every name
the lookup can produce has a bundled file.

The app icon (`Assets.xcassets/AppIcon.appiconset/icon-1024.png`) is original to this
project and is not derived from upstream artwork.

## Data

**Open-Meteo** — <https://open-meteo.com> — weather, air quality and geocoding under
CC BY 4.0. Air quality originates from the Copernicus Atmosphere Monitoring Service.
Attribution is shown on the main screen and in Settings, not only in this file.

## Not used

No upstream fonts, sounds, trademark assets or signing material are redistributed. The app
icon is original to this project. Weather data is fetched at runtime and never bundled.

## What this port changed, and what it did not

Nothing in upstream's repository was modified, and no upstream module was vendored: this is a
new Swift codebase that reimplements a defined subset of Breezy Weather 6.2.2's behaviour, plus
the artwork referenced above. The three places where the port deliberately differs are listed
in `02_parity/PARITY_SPEC.md` (card shapes, app-bar colour, and one deviation per omitted
feature), so a reader can tell a bug from a decision.

Under LGPL-3.0 this repository is the corresponding source for the binary it builds: the app is
LGPL-3.0, and anyone distributing a modified build must publish their changes under the same
terms and keep these notices.
