#!/bin/zsh
# Generate the README / marketing screenshots: 4 locales x 2 appearances, plus sheets.
#
#   usage: scripts/screenshots.sh [output-dir]      (default: docs/images)
#
# How it works, and why:
#
#  * The app is driven through `defaults write <bundleid> …`, then launched with
#    LaunchServices and NO launch arguments. Passing the same settings as launch
#    arguments stops SwiftUI's WindowGroup creating a window at all.
#  * `AppleLanguages` is set the same way. That is the only thing that actually
#    switches `String(localized:)` — SwiftUI's environment locale does not, and
#    `String(localized:locale:)` controls number formatting, not which .lproj is read.
#  * The language locks in at the first localized lookup, so each locale needs its own
#    app launch. Hence the relaunch loop.
#  * The window must be genuinely on screen before capture: a background-launched app
#    can get parked as a Stage Manager thumbnail, and both screencapture and
#    CGWindowList then faithfully capture that thumbnail instead of the real window.
#    We poll until the window reports onscreen at its full size.
#
# Needs a logged-in GUI session, and Screen Recording permission for the capturing
# terminal. Takes focus while it runs.
set -euo pipefail

HERE="${0:A:h}"; APP_DIR="${HERE:h}"; REPO="${APP_DIR:h}"

# --active brings the app to the front for each shot, which produces the ACTIVE window look:
# colored traffic lights and saturated accent controls. It also takes focus for about a
# minute. Default is background: same geometry, but the window is never key, so macOS draws
# it inactive — gray lights, dimmed toolbar, desaturated accents. That difference is real and
# cannot be faked; it is how an unfocused window genuinely looks.
ACTIVE=0
[[ "${1:-}" == "--active" ]] && { ACTIVE=1; shift; }

OUT="${1:-$REPO/docs/images}"
FIXTURE="${SNAPSHOT_FIXTURE:-$REPO/LocalFixtures/real_sample_GD.sav}"
BUNDLE_ID="app.davethediver.saveeditor"
APP="$APP_DIR/build/Build/Products/Debug/DaveTheDiverSaveEditor.app"
W=980; H=820

[[ -f "$FIXTURE" ]] || { echo "No fixture save at: $FIXTURE" >&2; exit 1; }

if [[ ! -d "$APP" ]]; then
  echo "Building…"
  ( cd "$APP_DIR" && xcodegen generate >/dev/null 2>&1
    xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj \
      -scheme DaveTheDiverSaveEditor -configuration Debug \
      -destination 'platform=macOS,arch=arm64' -derivedDataPath build \
      >/dev/null 2>&1 ) || { echo "build failed" >&2; exit 1; }
fi

mkdir -p "$OUT"
cleanup() { defaults delete "$BUNDLE_ID" 2>/dev/null || true
            pkill -9 -f "MacOS/DaveTheDiverSaveEditor" 2>/dev/null || true }
trap cleanup EXIT

# Background capture, via the ScreenCaptureKit helper. Built on demand.
#
# The old approach polled for an on-screen window and ran `open -a` in a loop to fight Stage
# Manager — which activates the app, so it repeatedly stole focus from whoever was using the
# machine. None of that was necessary: capture APIs read a window's backing store and do not
# care about frontmost-ness, z-order or occlusion. Launching HIDDEN (`open -j`) means Stage
# Manager has no stage entry to park, so the window stays full-size, and nothing takes focus.
#
# `-j` is not interchangeable with `-g`: a `-g` launch still gets parked at ~100x143.
HELPER="$HERE/.build/snapshot-capture"
if [[ ! -x "$HELPER" || "$HERE/snapshot-capture.swift" -nt "$HELPER" ]]; then
  mkdir -p "$HERE/.build"
  swiftc -parse-as-library -O "$HERE/snapshot-capture.swift" -o "$HELPER" || {
    echo "helper failed to build" >&2; exit 1; }
fi
WIN_H=$(( H + 52 ))          # content height + the title bar / toolbar band

capture() {   # capture <name> <lang> <appearance> [sheet]
  local name=$1 lang=$2 appearance=$3 sheet=${4:-}
  pkill -9 -f "MacOS/DaveTheDiverSaveEditor" 2>/dev/null || true; sleep 1

  defaults write "$BUNDLE_ID" AppleLanguages -array "$lang"
  defaults write "$BUNDLE_ID" SnapshotFixture -string "$FIXTURE"
  defaults write "$BUNDLE_ID" SnapshotAppearance -string "$appearance"
  defaults write "$BUNDLE_ID" SnapshotWidth -int $W
  defaults write "$BUNDLE_ID" SnapshotHeight -int $H
  if [[ -n "$sheet" ]]; then defaults write "$BUNDLE_ID" SnapshotSheet -string "$sheet"
  else defaults delete "$BUNDLE_ID" SnapshotSheet 2>/dev/null || true; fi

  if (( ACTIVE )); then open -a "$APP" >/dev/null 2>&1; else open -j -a "$APP" >/dev/null 2>&1; fi
  sleep 1.2                                  # let the fixture load and the strings resolve

  "$HELPER" "$BUNDLE_ID" "$OUT/$name.png" $W $WIN_H ${sheet:+--sheet}
}

# Warm up LaunchServices: the first launch after a build is slow enough that the
# window can miss the poll window.
open -a "$APP" >/dev/null 2>&1 || true; sleep 4
pkill -9 -f "MacOS/DaveTheDiverSaveEditor" 2>/dev/null || true; sleep 1

if (( ACTIVE )); then
  echo "Capturing to $OUT — --active: this WILL take focus for about a minute."
else
  echo "Capturing to $OUT (background — does not take focus)…"
fi
for loc in "en:en" "zh-Hans:zh-Hans" "zh-Hant:zh-Hant" "ko:ko"; do
  for appearance in light dark; do
    capture "main-${loc%%:*}-$appearance" "${loc##*:}" "$appearance" \
      || capture "main-${loc%%:*}-$appearance" "${loc##*:}" "$appearance" || true
  done
done
capture "sheet-raw-en-light"     en light raw      || true
capture "sheet-backups-en-light" en light backups  || true

echo "Done: $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ') images in $OUT"
