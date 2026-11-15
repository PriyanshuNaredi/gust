#!/usr/bin/env bash
# Unsigned IPA for sideloading (SideStore / LiveContainer).
#
#   ./07_tools/ipa-build.sh [version]
#
# Needs no Apple ID, no team, no provisioning profile. Verifies the archive itself:
# a zip that opens is not the same as an app that can be installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$ROOT/05_ios/Gust/project.yml" 2>/dev/null || echo 0.1.0)}"
OUT="$ROOT/06_release"
ARCHIVE="$OUT/Gust.xcarchive"
IPA="$OUT/Gust-$VERSION-unsigned.ipa"

mkdir -p "$OUT"
rm -rf "$ARCHIVE" "$IPA" "$OUT/Payload" "$OUT/verify"

echo "==> generate project"
( cd "$ROOT/05_ios/Gust" && xcodegen generate --spec project.yml >/dev/null )

echo "==> archive (no signing)"
LOG="$OUT/archive.log"
if ! xcodebuild archive \
      -project "$ROOT/05_ios/Gust/Gust.xcodeproj" \
      -scheme Gust \
      -configuration Release \
      -destination "generic/platform=iOS" \
      -archivePath "$ARCHIVE" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
      > "$LOG" 2>&1; then
  grep -E "error:" "$LOG" | head -20
  echo "FAIL: archive failed (log: $LOG)" >&2
  exit 1
fi
grep -q "ARCHIVE SUCCEEDED" "$LOG" || { echo "FAIL: no ARCHIVE SUCCEEDED in log" >&2; exit 1; }

echo "==> package Payload"
APP="$ARCHIVE/Products/Applications/Gust.app"
[ -d "$APP" ] || { echo "FAIL: no app in archive" >&2; exit 1; }
mkdir -p "$OUT/Payload"
cp -R "$APP" "$OUT/Payload/"
( cd "$OUT" && zip -qry "$(basename "$IPA")" Payload )

echo "==> verify the IPA"
V="$OUT/verify"
mkdir -p "$V"
unzip -q "$IPA" -d "$V"
BUNDLE="$V/Payload/Gust.app"

fail() { echo "FAIL: $1" >&2; exit 1; }
[ -d "$BUNDLE" ] || fail "Payload/Gust.app missing"
[ -x "$BUNDLE/Gust" ] || fail "executable missing"
[ -f "$BUNDLE/Assets.car" ] || fail "app icon asset catalogue missing"

# Version keys: an IPA without CFBundleVersion installs nowhere.
for key in CFBundleIdentifier CFBundleVersion CFBundleShortVersionString; do
  value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$BUNDLE/Info.plist" 2>/dev/null || true)
  [ -n "$value" ] || fail "$key missing from Info.plist"
done

for doc in NOTICE BREEZY_LICENSE BREEZY_LICENSE_ADDITIONAL; do
  [ -f "$BUNDLE/$doc.txt" ] || fail "licence document $doc.txt not bundled"
done

# A Mach-O built for the simulator cannot be sideloaded; check the platform.
PLATFORM=$(/usr/libexec/PlistBuddy -c 'Print :DTPlatformName' "$BUNDLE/Info.plist" 2>/dev/null || true)
[ "$PLATFORM" = "iphoneos" ] || fail "not an iOS build (platform: ${PLATFORM:-unknown})"

mkdir -p "$ROOT/06_release"
rm -rf "$OUT/Payload" "$V"

SIZE=$(du -h "$IPA" | cut -f1)
echo "OK: $IPA ($SIZE, version $VERSION, unsigned)"
