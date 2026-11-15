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

## Data

**Open-Meteo** — <https://open-meteo.com> — weather, air quality and geocoding under
CC BY 4.0. Air quality originates from the Copernicus Atmosphere Monitoring Service.
Attribution is shown on the main screen and in Settings, not only in this file.

## Not used

No upstream artwork, fonts or signing material is redistributed. The app icon is original
to this project.
