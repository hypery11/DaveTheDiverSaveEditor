#!/bin/zsh
# Self-feedback loop: (re)launch the Debug app with a fixture save preloaded
# (via the -snapshot-fixture launch arg, no keystrokes), then capture its window
# to a PNG an agent can Read. Build the app first if needed:
#   cd App && xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj \
#     -scheme DaveTheDiverSaveEditor -configuration Debug \
#     -destination 'platform=macOS,arch=arm64' -derivedDataPath build
#
# Usage: snapshot.sh [out.png] [category] [appearance]
#   category   = economy | restaurant | farm | inventory | advanced | ""(empty state, no fixture)
#   appearance = light | dark   (default: system)
set -e
HERE="${0:A:h}"                    # .../App/scripts
APP_DIR="${HERE:h}"                # .../App
REPO="${APP_DIR:h}"               # repo root
OUT="${1:-/tmp/dave_snapshot.png}"
CATEGORY="${2:-}"
APPEARANCE="${3:-}"
FIXTURE="$REPO/LocalFixtures/real_sample_GD.sav"
APP="$APP_DIR/build/Build/Products/Debug/DaveTheDiverSaveEditor.app"

[ -d "$APP" ] || { echo "app not built at $APP — build it first (see header)"; exit 1; }

ARGS=()
# category "empty" (or "none") => launch WITHOUT a fixture to capture the no-save state.
if [ "$CATEGORY" != "empty" ] && [ "$CATEGORY" != "none" ] && [ -f "$FIXTURE" ]; then
  ARGS+=(-snapshot-fixture "$FIXTURE")
fi
if [ -n "$CATEGORY" ] && [ "$CATEGORY" != "empty" ] && [ "$CATEGORY" != "none" ]; then
  ARGS+=(-snapshot-category "$CATEGORY")
fi
[ -n "$APPEARANCE" ] && ARGS+=(-snapshot-appearance "$APPEARANCE")

pkill -f "MacOS/DaveTheDiverSaveEditor" 2>/dev/null || true
sleep 0.6
open -a "$APP" --args "${ARGS[@]}"
sleep 2.5   # let the window appear + onAppear load the fixture + SwiftUI settle
"$HERE/snapshot-app.sh" "$OUT"
