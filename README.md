<p align="center">
  <img src="docs/images/logo.png" alt="DiveSaveEd" width="160">
</p>

<h1 align="center">DiveSaveEd — Dave the Diver Save Editor for macOS</h1>

**English** · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 14+](https://img.shields.io/badge/Platform-macOS%2014%2B-black.svg)](#requirements)
[![Apple Silicon + Intel](https://img.shields.io/badge/Apple%20Silicon-Intel-lightgrey.svg)](#requirements)

**A native macOS save editor for Dave the Diver.** Save editors for this game are almost all
Windows-only — this one is a real Mac app: it opens your save, edits it, and closes. No Wine, no
Cheat Engine, no process injection, no account, no network.

<p align="center">
  <img src="docs/images/main-en-light.png" alt="DiveSaveEd editing a Dave the Diver save on macOS" width="900">
</p>

## Requirements

macOS 14 or later, Apple Silicon or Intel. Works with the **Steam** version of the game on macOS.

> Nintendo Switch and PlayStation saves are **not** supported — those are console saves and this tool
> cannot read them.

## Install

Download the latest `.dmg` from [Releases](../../releases/latest) and drag the app to Applications.

The app is signed and notarized by Apple, so it opens normally — macOS will show the usual
"downloaded from the Internet" confirmation the first time.

## Features

**Currencies** — Gold, Bei, Artisan's Flame, Research Point, Cooksta Follower Count, Credit and Fake
points. Nudge by ±10/100/1000, type an exact value, or set the maximum. Reset restores the value the
save had when you opened it.

**Bulk fills** — one click each, or **Max Everything** for all of them at once:

| | |
|---|---|
| Restaurant | owned ingredients · all ingredients (DLC-aware) · branch stock · staff levels |
| Inventory | general items · craft materials (fish parts + DREDGE research parts/bones) · Sea People village · farm seeds · caught-fish grade |

**Browse and edit any single item by name** — the app ships an item database, so you search for what
you actually want instead of hunting for numeric IDs.

**Everything is reversible** — every bulk action can be undone in-app, every write makes a timestamped
backup first, and there is a restore UI to roll back to any of them.

**Read-only raw inspector** — search the entire decoded save as formatted JSON. Deliberately read-only:
hand-editing raw values can set progression flags out of order and soft-lock a run.

**Multiple save slots** — picks up every save the game has and lets you choose.

**Four languages** — English, 简体中文, 繁體中文, 한국어.

<p align="center">
  <img src="docs/images/main-zh-Hant-light.png" alt="繁體中文介面" width="440">
  <img src="docs/images/main-ko-dark.png" alt="한국어 인터페이스 (다크 모드)" width="440">
</p>

## Where is the Dave the Diver save file on Mac?

Dave the Diver stores its macOS saves here:

```
~/Library/Application Support/com.nexon.dave/SteamSData/<steam-id>/
```

Some installs use this path instead:

```
~/Library/Application Support/nexon/DAVE THE DIVER/SteamSData/
```

Both are checked automatically — the app finds your saves without being told where they are. The files
are named `GameSave_XX_GD.sav`.

`~/Library` is hidden in Finder. To open it yourself: **Finder → Go → Go to Folder…** (`⇧⌘G`), paste the
path, press Return.

## ⚠️ Steam Cloud will silently undo your edits

This is the single most common reason an edit "doesn't work". When Steam launches, it sees your local
save differs from the cloud copy and **restores the old cloud version over your edit** before the game
even loads. Do it in this order:

1. **Quit Dave the Diver completely.** The app refuses to write while the game is running.
2. **Turn off Steam Cloud for this game** — Steam Library → right-click **Dave the Diver** →
   **Properties** → **General** → uncheck **Keep game saves in the Steam Cloud**.
3. **Edit and save.** A timestamped backup is written first, automatically.
4. **Launch the game.** Your edit is now the version that loads.

## FAQ

### Will I get banned for using this?

No. Dave the Diver is a single-player game with no multiplayer, no leaderboards, and no anti-cheat
software. This tool edits a file on your own computer while the game is closed. It never attaches to
the game process, never reads or writes game memory, and never touches the game executable.

### Why did my edits disappear after launching the game?

Almost always Steam Cloud — see the section above. The other cause is the opening tutorial: a few
values are hard-scripted during it and the game overwrites them. Edits stick reliably once you're past
that point.

### Does it work with Chinese, Korean, or Japanese saves?

Yes. Saves containing non-ASCII text are read and written correctly, with no corrupted characters.

### Does this work on Intel Macs?

Yes — the app is a universal build for Apple Silicon and Intel.

### Does it support the "In the Jungle" DLC?

Partly, and the limit is worth knowing before you rely on it. A save from a game with the DLC
installed loads and writes correctly — anything the app doesn't recognise is preserved
untouched — and bulk fills only inject content your save reports as installed. But the bundled
item database predates *In the Jungle*, so Jungle-only items aren't listed by name and aren't
included in the bulk fills. Earlier DLC content, including the DREDGE collab, is covered.

### Can I undo something I didn't mean to do?

Yes, twice over: **Undo last edit** reverses a bulk action in-app before you ever write, and every
write makes a timestamped backup you can restore from the **Restore from Backup** window.

### Does it work with the Xbox / Microsoft Store version?

Not on macOS — that version isn't available for Mac. This tool targets the macOS Steam save location.

## Is this safe?

Safety is a design constraint, not an afterthought:

- **Refuses to write while Dave the Diver is running**, or while the save file is open elsewhere.
- **Automatic timestamped backup before every write**, with a restore UI.
- **Bulk undo** for every bulk operation.
- **A change preview** before anything is written.
- **Skips perishable aberration fish** (the DREDGE collab catch) in bulk fills — the game discards
  stockpiled aberrations on load, so filling them would wipe your real catch.
- **Open source under MIT.** Read every line before you run it.

This exists so you can back up, repair, and un-grind your own single-player save.

## Not planned

- **Nintendo Switch / PlayStation saves** — those are encrypted console saves; this tool
  cannot read them.
- **Windows or Linux builds** — this is a Mac app.
- **Anything that attaches to the running game** — trainers, memory editing, overlays.
- **Modifying the game's own code or assets.**
- **Auto-update, telemetry, or any network feature.** The app makes no network requests
  at all, and that is a design guarantee rather than an oversight.

## Build from source

```bash
git clone https://github.com/hypery11/DaveTheDiverSaveEditor.git
cd DaveTheDiverSaveEditor
swift test                                  # engine tests
cd App && xcodegen generate                 # generate the Xcode project
xcodebuild -scheme DaveTheDiverSaveEditor test
```

There's also `dtdcli`, a headless companion CLI over the same engine, for scripting.

## Support the project

DiveSaveEd is free and MIT-licensed — no ads, no paid version, nothing locked behind a
payment. If it saved you a grind and you want to put something toward the research behind it
(decoding the save format, keeping the item data current, checking terminology against the
game's own localization files), there's a link:

**[fsd.fkey.id](https://fsd.fkey.id/)**

It is **crypto only** — USDC on Base is the cheapest route — so if that isn't something you
already use, don't go out of your way. A bug report, or a fix to one of the four
translations, is genuinely worth more to this project than a few dollars.

> The only official donation link is this one and the one on the project site. Anywhere else
> collecting "for DiveSaveEd" is not us — a crypto address in a fork or a re-hosted `.dmg`
> can be swapped without anyone being able to tell.

## Contributing

Translations, bug reports and fixes are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Disclaimer

> This is an unofficial, fan-made tool. It is not affiliated with, authorized by, endorsed by, or
> sponsored by MINTROCKET, Nexon Korea Corporation, or any of their affiliates. "Dave the Diver" and
> all related names, logos, and characters are trademarks of their respective owners and are used here
> only descriptively, to identify the game this tool works with. This tool edits save files on your own
> computer; it does not modify, patch, or redistribute any part of the game, and it **contains no game
> code and no game assets**. It is free, contains no advertising, and is not sold. Use at your own risk
> — always keep backups.

## License

MIT — see [LICENSE](LICENSE). Third-party notices: [NOTICE](NOTICE) and
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).
