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

The app ships English, Simplified Chinese, Traditional Chinese and Korean. More are
welcome, as are corrections — if a string reads awkwardly to a native speaker, that's a
bug, and you don't need to be a programmer to fix it.

Pick whichever of these suits you. Both end up in the same place.

### With a translation tool (the lossless route)

This is Apple's own format, so nothing is lost in the round trip and you can use Poedit,
Crowdin, Trados or any tool that reads XLIFF.

```bash
cd App
xcodebuild -exportLocalizations -project DaveTheDiverSaveEditor.xcodeproj \
  -scheme DaveTheDiverSaveEditor -localizationPath ../loc -exportLanguage ko
# translate ../loc/ko.xcloc, then:
xcodebuild -importLocalizations -project DaveTheDiverSaveEditor.xcodeproj \
  -scheme DaveTheDiverSaveEditor -localizationPath ../loc/ko.xcloc
```

### With a spreadsheet (no Xcode needed)

```bash
Scripts/loc_csv.py export ko ko.csv     # open in Numbers, Excel or Google Sheets
# fill in the `translation` column, save as CSV, then:
Scripts/loc_csv.py import ko ko.csv
```

**You don't have to run the import yourself.** Send the filled-in CSV however suits you —
attach it to a [translation issue](../../issues/new?template=translation.yml), or post it
wherever you found the app — and it'll be merged for you. Tell us how you'd like to be
credited.

### Two rules that matter more than style

1. **Format specifiers must survive exactly.** If the English says
   `Maxed inventory items (%lld slots).` your translation needs exactly one `%lld`. Getting
   this wrong crashes the app in your language only, so it's checked mechanically:

   ```bash
   python3 Scripts/check_catalog.py
   ```

   CI runs this on every push. If your language needs the values in a different order than
   English, switch to numbered form so they still bind correctly — `Add %lld to %@` becomes
   `為 %2$@ 增加 %1$lld`, where `%1$` is the first English value and `%2$` the second.

2. **Use the game's own words.** The game itself is officially localized into these
   languages, so players expect the in-game terms for Bei, Artisan's Flame, Cooksta, the Sea
   People village and so on. A literal translation of the English will read wrong to them.
   [`docs/TERMINOLOGY.md`](docs/TERMINOLOGY.md) records the terms we settled on, the
   evidence behind each, and the ones still unverified — read it before changing Chinese,
   and add to it if you settle one.

   `check_catalog.py` also enforces a small blocklist from that file. It exists because
   Traditional and Simplified Chinese are **separate official localizations of this game**,
   not one language in two scripts: converting characters between them imports the other
   region's vocabulary, which is how `鮫人村` and `匠人之火` once shipped in Traditional. If
   you work in either, translate from the English — never from the other one.

Keep it short, too — most of these are buttons and table rows in a dense window.

A brand-new language ships marked "community preview" until a second native speaker has
looked it over. Corrections to an existing language only need one person.

## Scope

This is a **save editor**: it edits save files while the game is closed. Things that attach to the
running game — trainers, memory editing, overlays — are out of scope, and so is anything that
touches the game's own code or assets.
