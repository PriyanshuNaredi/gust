#!/usr/bin/env bash
# Two layers, deliberately split: the package tests are the inner loop (well under
# a second), the UI tests drive a real simulator (~20 s and up).
#
#   ./07_tools/macos-tests.sh [all|logic|ui]
#
# Every layer asserts a NON-ZERO executed count. A filter that matches nothing
# must fail, not pass quietly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${SIM:-C5E1129B-3ED4-4BD0-8073-5E1FA6B8A10D}"
DERIVED="${DERIVED:-/tmp/dd-gust}"
LAYER="${1:-all}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

run_logic() {
  echo "==> logic (BreezyUnits)"
  local out
  out=$( cd "$ROOT/05_ios/BreezyUnits" && swift test 2>&1 )
  local count
  count=$(printf "%s\n" "$out" | sed -n 's/.*Executed \([0-9][0-9]*\) tests.*/\1/p' | sort -rn | head -1)
  printf "%s\n" "$out" | grep -E "error:|failed \(" && { echo "FAIL: logic tests failed" >&2; exit 1; }
  [ "${count:-0}" -gt 0 ] || { echo "FAIL: logic layer executed 0 tests" >&2; exit 1; }
  echo "logic: $count tests passed"
}

run_ui() {
  echo "==> ui (XCUITest)"
  local out
  out=$( cd "$ROOT/05_ios/Gust" \
    && xcodegen generate --spec project.yml >/dev/null \
    && xcodebuild test -project Gust.xcodeproj -scheme Gust \
         -destination "id=$SIM" -derivedDataPath "$DERIVED" 2>&1 )
  local count
  count=$(printf "%s\n" "$out" | sed -n 's/.*Executed \([0-9][0-9]*\) tests.*/\1/p' | sort -rn | head -1)
  printf "%s\n" "$out" | grep -E "error:|TEST FAILED" && { echo "FAIL: ui tests failed" >&2; exit 1; }
  [ "${count:-0}" -gt 0 ] || { echo "FAIL: ui layer executed 0 tests" >&2; exit 1; }
  echo "ui: $count tests passed"
}

case "$LAYER" in
  logic) run_logic;;
  ui)    run_ui;;
  all)   run_logic; run_ui;;
  *) echo "usage: $0 [all|logic|ui]" >&2; exit 2;;
esac
echo "OK: $LAYER green"
