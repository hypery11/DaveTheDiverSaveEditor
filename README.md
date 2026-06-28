# Dave The Diver Save Editor

> The first **native macOS (Apple Silicon)** save editor for the game *Dave the Diver* —
> free, open-source, 100% local, and the only one that edits **Chinese/Korean saves without corrupting them**.

**Status:** early development. The pure-Swift core (`DaveSaveCore`) is being built first (TDD);
the SwiftUI app follows. See [`docs/superpowers/specs`](docs/superpowers/specs) for the design
and [`docs/superpowers/plans`](docs/superpowers/plans) for the implementation plan.

## Why this exists

The excellent [DaveSaveEd](https://github.com/FNGarvin/DaveSaveEd) by FNGarvin is Windows-only.
Mac players have had to run it under Wine, hand-edit JSON in a terminal, or pay a stranger ~$20.
This project brings a real, native, trustworthy editor to the Mac — and fixes a correctness bug:
the upstream byte-level codec corrupts saves that contain non-ASCII names (it produced 121 garbage
characters on a real Chinese save where this editor produces zero).

## Planned v1 features

- View and edit Gold, Bei, Artisan's Flame, and Follower Count (exact value **or** one-click Max, with Reset).
- Max owned ingredients / max all ingredients (DLC-aware).
- Auto-detect your macOS save, read-only viewer, change-preview-before-write, automatic backups.

## How to use — and the #1 gotcha (read this!)

**⚠️ Steam Cloud will silently undo your edits unless you turn it off first.** This is the single
most common reason a save edit "doesn't work": when Steam launches, it sees your locally-edited save
differs from the cloud copy and **overwrites your edit with the old cloud backup** before the game even
loads. Always follow this order:

1. **Quit Dave the Diver completely** (the game must not be running while you edit).
2. **Disable Steam Cloud for this game:** Steam Library → right-click **Dave the Diver** → **Properties**
   → **General** → uncheck **"Keep game saves in the Steam Cloud for Dave the Diver"**.
3. **Edit and save** with this tool (it makes an automatic timestamped backup before writing).
4. **Launch the game.** Your local edit now takes priority and persists.

Other notes:

- **Save location (macOS):** `~/Library/Application Support/com.nexon.dave/SteamSData/<steam-id>/` —
  the tool auto-detects the newest `GameSave_XX_GD.sav`. (Some installs use
  `…/nexon/DAVE THE DIVER/SteamSData/…` instead; both are checked.)
- **Early game:** during the opening tutorial, a few values (e.g. gold before the sushi-bar quest) are
  hard-scripted by the game and will override save edits. Edits "stick" reliably once you're past that.
- **Backups & restore:** every write is backed up first. To revert, quit the game and copy a backup
  `GameSave_XX_GD.sav` back into the save folder above.

## Credits

Inspired by and crediting [FNGarvin/DaveSaveEd](https://github.com/FNGarvin/DaveSaveEd) (MIT) and
[WhiteMinds' save-codec reverse-engineering](https://github.com/WhiteMinds/dave-diver-expansion).
See [NOTICE](NOTICE). Not affiliated with Mintrocket or Nexon.

## License

MIT — see [LICENSE](LICENSE).
