#!/bin/zsh
# Capture the RUNNING DaveTheDiverSaveEditor main window to a PNG, fully
# autonomously (no keystrokes, no human clicking). Works even when the window
# is minimized or backgrounded: a LaunchServices reopen event (`open <bundle>`)
# surfaces it — NSRunningApplication.activate() cannot, due to macOS cooperative
# activation. The window's backing store is then captured with `screencapture -l`.
#
# Usage: snapshot-app.sh <output.png>
# Requires: the app already running; the caller holds Screen Recording permission.
set -e
OUT="${1:-/tmp/dave_snapshot.png}"
APPNAME="DaveTheDiverSaveEditor"

PID=$(pgrep -f "MacOS/$APPNAME" | head -1)
[ -z "$PID" ] && { echo "app not running"; exit 1; }

EXE=$(ps -o comm= -p "$PID")
BUNDLE="${EXE%/Contents/MacOS/*}"   # -> .../DaveTheDiverSaveEditor.app

open "$BUNDLE"   # surface / un-minimize

ID=""
for i in $(seq 1 20); do
  ID=$(swift - "$PID" <<'SWIFT'
import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
guard let l = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String:Any]] else { print(""); exit(0) }
var best = -1, bestArea = 0
for w in l {
  guard (w[kCGWindowOwnerPID as String] as? Int) == pid,
        let bb = w[kCGWindowBounds as String] as? [String:Any],
        let ww = bb["Width"] as? Double, let hh = bb["Height"] as? Double,
        let num = w[kCGWindowNumber as String] as? Int else { continue }
  let a = Int(ww*hh)
  if a > bestArea { bestArea = a; best = num }
}
print(bestArea > 120_000 ? String(best) : "")   // require a real window, not the Dock thumbnail
SWIFT
)
  [ -n "$ID" ] && break
  open "$BUNDLE"
  sleep 0.3
done
[ -z "$ID" ] && { echo "could not surface a large on-screen window"; exit 2; }

for i in 1 2 3; do
  if /usr/sbin/screencapture -x -o -l"$ID" "$OUT" && [ -s "$OUT" ]; then
    echo "wrote $OUT (window id=$ID, pid=$PID)"; exit 0
  fi
  sleep 0.4
done
echo "capture failed"; exit 3
