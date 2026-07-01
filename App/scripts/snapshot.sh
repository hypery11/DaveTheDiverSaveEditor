#!/bin/zsh
# Self-feedback loop: (re)launch the Debug app with a fixture save preloaded
# (via the -snapshot-fixture launch arg, no keystrokes), then capture its window
# to a PNG an agent can Read. Build the app first if needed:
#   cd App && xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj \
#     -scheme DaveTheDiverSaveEditor -configuration Debug \
#     -destination 'platform=macOS,arch=arm64' -derivedDataPath build
#
# Usage: snapshot.sh [out.png] [fixture.sav]
set -e
HERE="${0:A:h}"                    # .../App/scripts
APP_DIR="${HERE:h}"                # .../App
REPO="${APP_DIR:h}"               # repo root
OUT="${1:-/tmp/dave_snapshot.png}"
FIXTURE="${2:-$REPO/LocalFixtures/real_sample_GD.sav}"
APP="$APP_DIR/build/Build/Products/Debug/DaveTheDiverSaveEditor.app"

[ -d "$APP" ] || { echo "app not built at $APP — build it first (see header)"; exit 1; }

pkill -f "MacOS/DaveTheDiverSaveEditor" 2>/dev/null || true
sleep 0.6
if [ -f "$FIXTURE" ]; then
  open -a "$APP" --args -snapshot-fixture "$FIXTURE"
else
  echo "fixture not found ($FIXTURE) — launching empty state"; open -a "$APP"
fi
sleep 2.5   # let the window appear + onAppear load the fixture + SwiftUI settle
"$HERE/snapshot-app.sh" "$OUT"
