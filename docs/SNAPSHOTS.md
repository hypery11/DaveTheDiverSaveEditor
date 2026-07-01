# Autonomous visual feedback loop

A way to **see the running app as a PNG** without a human clicking or screenshotting —
so UI work can be iterated see → change → see.

## Quick use

```bash
# 1. Build the Debug app (once, or after code changes):
cd App && xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj \
  -scheme DaveTheDiverSaveEditor -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build

# 2. Relaunch it with a fixture save preloaded and capture its window:
App/scripts/snapshot.sh /tmp/economy.png            # default fixture: LocalFixtures/real_sample_GD.sav
App/scripts/snapshot.sh /tmp/economy.png /path/to/other.sav

# 3. Read /tmp/economy.png.
```

To capture whatever the *already-running* instance shows (any category — click first, or
just to grab the current state), use the lower-level script directly:

```bash
App/scripts/snapshot-app.sh /tmp/current.png
```

## How it works

- **`-snapshot-fixture <path>` launch arg** (`DaveTheDiverSaveEditorApp.swift`): on launch the
  app loads that save instead of auto-detecting, so the captured cards are populated. No
  keystrokes. Guarded — normal launches are unaffected.
- **`snapshot-app.sh`**: the app window is often *minimized* when backgrounded; from a non-GUI
  caller `NSRunningApplication.activate()` can't restore it (macOS cooperative activation), but a
  LaunchServices **reopen event (`open <bundle>`)** does. It then finds the largest on-screen
  window for the app's PID via `CGWindowListCopyWindowInfo` and captures its backing store with
  `screencapture -x -o -l<windowid>` (works even if occluded). A short retry loop absorbs a
  transient right after surfacing.
- **`snapshot.sh`**: kills the old instance, relaunches with the fixture arg, waits, calls
  `snapshot-app.sh`.

## Requirements & caveats

- **Screen Recording permission** for the host process (Terminal/agent). Without it, captures come back black.
- Needs an **active, unlocked Aqua session** for the same user (fails over pure SSH / locked screen).
- It **surfaces/focuses** the app window (a watching user sees it pop forward). No keystrokes are sent.
- The captured window is the real `NavigationSplitView` (chrome, sidebar, cards, live theme/data).

## Alternatives evaluated (2026-07-01)

| Approach | Full window? | Notes |
|---|---|---|
| **screencapture + `open`** (this) | ✅ real window | zero code change, ~0.5s; primary for "see the running app". |
| **XCUITest screenshot** | ✅ real window | CI-grade/deterministic, no focus theft; heavier (UI-test target + `xcresulttool export`). The launch-arg fixture seam here also serves it. |
| **SwiftUI `ImageRenderer`** | components only | fast, headless, zero-dep; renders cards/panes but **not** `NavigationSplitView` (shows an "unavailable" placeholder). Needs the views in a shared library to snapshot the real ones. |
| swift-snapshot-testing | components only | same off-window limit as ImageRenderer + heavy deps (swift-syntax). Not worth it here. |
