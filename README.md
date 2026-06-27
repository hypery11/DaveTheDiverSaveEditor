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

## Credits

Inspired by and crediting [FNGarvin/DaveSaveEd](https://github.com/FNGarvin/DaveSaveEd) (MIT) and
[WhiteMinds' save-codec reverse-engineering](https://github.com/WhiteMinds/dave-diver-expansion).
See [NOTICE](NOTICE). Not affiliated with Mintrocket or Nexon.

## License

MIT — see [LICENSE](LICENSE).
