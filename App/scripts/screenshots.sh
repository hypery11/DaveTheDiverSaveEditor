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

# Print the window id of the app's real, on-screen main window (empty if not ready).
find_window() {
  /usr/bin/swift - "$W" <<'SWIFT' 2>/dev/null
import CoreGraphics; import Foundation
let want = Int(CommandLine.arguments[1]) ?? 0
let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    guard let owner = w[kCGWindowOwnerName as String] as? String, owner.contains("Diver"),
          (w[kCGWindowLayer as String] as? Int) == 0,
          let b = w[kCGWindowBounds as String] as? [String: Any],
          let width = b["Width"] as? Double, Int(width) == want,
          let id = w[kCGWindowNumber as String] as? Int else { continue }
    print(id); exit(0)
}
SWIFT
}

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

  # Stage Manager can park a freshly launched app's window as a ~100x143 thumbnail.
  # The window is laid out correctly, but both screencapture and CGWindowList then
  # faithfully capture the thumbnail. Re-issuing `open -a` re-activates the app and
  # pulls it back out, so nudge it while polling for the real, full-width window.
  local id="" i
  for i in {1..24}; do
    (( i % 4 == 1 )) && open -a "$APP" >/dev/null 2>&1
    id=$(find_window); [[ -n "$id" ]] && break
    sleep 0.5
  done
  [[ -n "$id" ]] || { echo "  ! $name: window never surfaced (Stage Manager?)"; return 1; }
  sleep 1.2                                   # let content settle before the shot
  /usr/sbin/screencapture -x -o -l"$id" "$OUT/$name.png" && echo "  ✓ $name"
}

# Warm up LaunchServices: the first launch after a build is slow enough that the
# window can miss the poll window.
open -a "$APP" >/dev/null 2>&1 || true; sleep 4
pkill -9 -f "MacOS/DaveTheDiverSaveEditor" 2>/dev/null || true; sleep 1

echo "Capturing to $OUT (takes focus for ~1 min)…"
for loc in "en:en" "zh-Hans:zh-Hans" "zh-Hant:zh-Hant" "ko:ko"; do
  for appearance in light dark; do
    capture "main-${loc%%:*}-$appearance" "${loc##*:}" "$appearance" \
      || capture "main-${loc%%:*}-$appearance" "${loc##*:}" "$appearance" || true
  done
done
capture "sheet-raw-en-light"     en light raw      || true
capture "sheet-backups-en-light" en light backups  || true

echo "Done: $(ls "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ') images in $OUT"
