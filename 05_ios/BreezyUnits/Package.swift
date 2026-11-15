// swift-tools-version:5.9
import PackageDescription

// Units module ported from Breezy Weather's `weather-unit` (LGPL-3.0).
// Original: https://github.com/breezy-weather/breezy-weather (tag v6.2.2)
// This port keeps the reference-unit storage model and the conversion maths, and
// replaces the Android-only parts (Context, R strings, android.icu.MeasureUnit,
// LocalePreferences) with a small formatting layer of our own.
let package = Package(
    name: "BreezyUnits",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "BreezyUnits", targets: ["BreezyUnits"])
    ],
    targets: [
        .target(name: "BreezyUnits"),
        .testTarget(name: "BreezyUnitsTests", dependencies: ["BreezyUnits"])
    ]
)
