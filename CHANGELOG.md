# Changelog

Notable changes to DiveSaveEd. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Anything that could change what gets written to a save file is called out explicitly — that is
the part of a release worth reading before you upgrade.

## [Unreleased]

Not in any released build yet — v1.0.0's `.dmg` predates all of it.

### Fixed

- The in-app donation prompt sent people straight to the crypto wallet page, which is titled
  "Send to fsd" over a bare address and names neither this app nor its author. It now opens the
  project's own support page, **in the app's language**, which explains who `fsd` is and
  discloses crypto-only first. The About window and the Help menu already did this; the prompt
  that opens at launch and after every third save — the one nearly everybody sees — did not.
- Chinese: the donation prompt said 物品 where the game ships 道具, and six Traditional Chinese
  strings, including the Steam Cloud warning, used ASCII commas between Han characters where
  every other string uses full-width punctuation.
- The About window's non-affiliation line stacked three synonyms; it now says it once.

## [1.0.0] — 2026-08-03

First public release. A native macOS save editor for Dave the Diver: no Wine, no Cheat Engine,
no process injection, no account, and no network access at any point.

### Added

- **Seven currencies** — Gold, Bei, Artisan's Flame, Research Point, Cooksta Follower Count,
  Credit and Fake Point. Nudge by ±10/100/1000, type an exact value, or set the maximum;
  each row reverts individually to the value the save had when it was opened.
- **Nine one-click bulk fills** — owned ingredients, all ingredients (DLC-aware), branch stock,
  staff levels, general inventory, crafting materials, Sea People Village storage, farm seeds
  and caught-fish grade — plus **Run All Fills**, which runs them in one action (owned
  ingredients is folded into all ingredients there, since the latter supersedes it).
- **Item search** — browse and edit any single item by name, from a bundled reference database,
  instead of hunting for numeric IDs.
- **Read-only raw inspector** — search the whole decoded save as formatted JSON. Read-only on
  purpose: hand-editing raw values can set progression flags out of order and soft-lock a run.
- **Multiple save slots**, detected automatically.
- **Four languages** — English, 简体中文, 繁體中文, 한국어. Every in-game term was checked
  against the game's own shipped localization data rather than translated from English; see
  [`docs/TERMINOLOGY.md`](docs/TERMINOLOGY.md).
- **Steam Cloud pre-flight check** — warns when Steam has a staged copy of the slot you are
  about to edit, which is the most common reason an edit appears not to have worked.

### Save safety

- Refuses to write while the game is running, or while the save file is held open.
- Writes a timestamped backup before every write, with an in-app restore window.
- Reads the file back after writing and verifies it before reporting success.
- ⌘Z undo and redo, covering both currency edits and bulk fills.
- Skips perishable aberration fish, which the game discards on load.
- Shows exactly what will change before anything is written.
- The save codec works on UTF-16 code units rather than bytes, so Chinese, Korean and Japanese
  saves round-trip byte-identically instead of being corrupted.

### Distribution

- Signed and notarized by Apple; universal binary for Apple Silicon and Intel.
- Published SHA-256 and a GitHub build-provenance attestation for every release artifact.

[Unreleased]: https://github.com/hypery11/DaveTheDiverSaveEditor/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hypery11/DaveTheDiverSaveEditor/releases/tag/v1.0.0
