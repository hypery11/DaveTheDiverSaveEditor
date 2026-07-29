# Contributing

Thanks for helping out. Bug reports, fixes, and translations are all welcome.

## Reporting a bug

Please include: your macOS version, whether you're on Apple Silicon or Intel, the app version, and
what the app said. If a save failed to load or write, say which — and **never attach a real save file
to a public issue**; it contains your progress and your Steam ID. If a save is needed to reproduce
something, we'll arrange it privately.

## Building from source

You need Xcode 16 or later. You do **not** need a paid Apple Developer account — the
project is configured for ad-hoc local signing (`CODE_SIGN_IDENTITY = "-"`), so it builds
and runs with no team set. An unexplained signing failure is the usual reason someone
gives up here, so if you hit one, that's a bug in these instructions — please say so.

```bash
git clone https://github.com/hypery11/DaveTheDiverSaveEditor.git
cd DaveTheDiverSaveEditor

swift test                     # engine tests — no Xcode project, no signing needed

brew install xcodegen          # the .xcodeproj is generated, not committed
cd App && xcodegen generate
xcodebuild -scheme DaveTheDiverSaveEditor -destination 'platform=macOS' test
```

CI runs exactly these commands. **The engine is a plain Swift package**, so most bugs in
save parsing, the codec or the bulk operations can be fixed and tested with `swift test`
alone — no Xcode, no xcodegen, no signing.

The project is split in two:

- **`Sources/DaveSaveCore/`** — the pure engine. Save codec, an order-preserving JSON DOM, typed
  accessors, and the bulk operations. No UI, no AppKit. This is where the tests live.
- **`App/Sources/`** — the SwiftUI app. `SaveEditorModel` is the single coordination layer.

`CONTEXT.md` explains the load-bearing pieces and the vocabulary used in code review.

Two conventions worth knowing before you open a PR:

- **An editable value is one row.** Adding a currency-like field means adding a row to
  `editableScalars` in `SaveDocument.swift` and a `Currency` case — not scattered getters and setters.
- **A bulk operation is one entry.** Add it to `BulkAction.catalog`; the UI rows, "Max Everything" and
  the model entry point all derive from that one definition.

Please keep tests passing, and add one for anything that touches the save format — a bug there costs
someone their progress.

## Translations

The app ships English, Simplified Chinese, Traditional Chinese and Korean. More are welcome, as are
corrections to the existing ones — if a string reads awkwardly to a native speaker, that's a bug.

All UI text lives in one file: **`App/Sources/Localizable.xcstrings`** (a String Catalog).

**The easy way** — open `App/DaveTheDiverSaveEditor.xcodeproj` in Xcode, select
`Localizable.xcstrings`, pick your language, and fill in the empty rows. Xcode shows the English
source beside each one.

**Without Xcode** — the catalog is JSON. Each entry looks like this:

```json
"Max Everything" : {
  "localizations" : {
    "ko" : { "stringUnit" : { "state" : "translated", "value" : "전부 최대" } }
  }
}
```

Adding a new language: use its standard code (`ja`, `de`, `fr`, …) as the key, and set
`"state": "translated"`.

**Two rules that matter more than style:**

1. **Format specifiers must survive exactly.** If the English is `Maxed inventory items (%lld slots).`
   your translation needs exactly one `%lld`. Same for `%@`. Getting this wrong crashes the app at
   runtime, so it's the one thing to double-check.

   If your language needs the values in a *different order* than English, you must switch to numbered
   form so they still bind correctly — `Add %lld to %@` becomes `为 %2$@ 增加 %1$lld`, where `%1$`
   is the first English value and `%2$` the second.

2. **Use the game's own words.** The game itself is officially localized into these languages, so
   players expect the in-game terms for Bei, Artisan's Flame, Cooksta, the Sea People village, and so
   on. A literal translation of the English will read wrong to them.

Keep it short, too — most of these are buttons and table rows in a dense window.

To check your work, run the app in your language:

```bash
xcodebuild -scheme DaveTheDiverSaveEditor \
  -destination 'platform=macOS,arch=arm64' build
open App/build/.../DiveSaveEd.app --args -AppleLanguages '(ko)'
```

The test suite is pinned to English on purpose, so translations can't break it.

## Scope

This is a **save editor**: it edits save files while the game is closed. Things that attach to the
running game — trainers, memory editing, overlays — are out of scope, and so is anything that
touches the game's own code or assets.
