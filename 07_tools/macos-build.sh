#!/usr/bin/env bash
# Build, install and launch Gust on the pinned simulator.
#
#   ./07_tools/macos-build.sh [--run]
#
# Regenerates the Xcode project first, unconditionally: a stale project silently
# excludes new files, and when the new file is a test the suite runs zero tests
# and still reports success. That is how a green build lies.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$ROOT/05_ios/Gust"
SIM="${SIM:-C5E1129B-3ED4-4BD0-8073-5E1FA6B8A10D}"   # iPhone 16, iOS 18.0
DERIVED="${DERIVED:-/tmp/dd-gust}"
BUNDLE_ID=dev.priyanshu.gust

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

echo "==> units package tests"
( cd "$ROOT/05_ios/BreezyUnits" && swift test --quiet 2>&1 | tail -2 )

echo "==> xcodegen"
( cd "$PROJ" && xcodegen generate --spec project.yml >/dev/null )

echo "==> build"
xcodebuild -project "$PROJ/Gust.xcodeproj" -scheme Gust -configuration Debug \
  -destination "id=$SIM" -derivedDataPath "$DERIVED" build 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Gust.app"
[ -d "$APP" ] || { echo "FAIL: no app bundle at $APP" >&2; exit 1; }

# The bundle must carry a real version or simctl refuses to install it (code 22).
BUILD_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist" 2>/dev/null || echo MISSING)
[ "$BUILD_VERSION" != "MISSING" ] || { echo "FAIL: CFBundleVersion missing from Info.plist" >&2; exit 1; }

if [ "${1:-}" = "--run" ]; then
  echo "==> install + launch"
  xcrun simctl boot "$SIM" 2>/dev/null || true
  xcrun simctl install "$SIM" "$APP"
  xcrun simctl launch "$SIM" "$BUNDLE_ID"
fi

echo "OK: Gust $BUILD_VERSION built for $SIM"
