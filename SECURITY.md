# Security Policy

## Reporting a vulnerability

Please report security issues privately via GitHub's
[private vulnerability reporting](../../security/advisories/new) rather than a public issue.

I'll acknowledge within a few days. Since this is a small project maintained in spare time, please
allow reasonable time for a fix before disclosing publicly.

## Scope

This app runs entirely on your machine. It makes **no network requests** — no telemetry, no update
check, no analytics. It reads and writes:

- your Dave the Diver save files, only when you ask it to;
- timestamped backups under `~/Library/Application Support/app.davethediver.saveeditor/Backups/`;
- a read-only, bundled SQLite database of item identifiers.

Things worth reporting: anything that could corrupt or destroy a save, any way to make the app write
outside the paths above, or a supply-chain problem with a release artifact.

## Verifying a release

Releases are built from tagged source and signed and notarized by Apple. Each release publishes the
SHA-256 of its artifacts — check it before running:

```bash
shasum -a 256 DiveSaveEd-macOS-vX.Y.Z.dmg
```

You can also confirm the notarization ticket:

```bash
spctl -a -vvv -t install /Applications/DiveSaveEd.app
```
