# Domain glossary — DaveSaveEd

Names for the load-bearing seams in this Dave the Diver save editor. Architecture
reviews and future work should use these terms (and the deep-module vocabulary:
module, interface, depth, seam, leverage, locality).

## Engine (`Sources/DaveSaveCore/`)

- **OrderedJSON** — a lexeme-preserving JSON DOM (enum: object / array / scalar). Every
  untouched token re-emits its verbatim source, so decode → edit → serialize is
  byte-identical for the game's compact JSON. The reference deep module: tiny interface
  (`value(at:)` / `setScalar` / `setMember`) over real complexity.
- **SaveDocument** — typed accessors over the DOM (load / encode / prettyJSON + the edits).
- **editableScalars** — the single table of currency-like values on `SaveDocument`:
  `(id, dotted, path, lo, hi)` per row. `Currency.rawValue` is the `id`. Generic
  `intValue(forID:)` / `setInt(forID:)` and the looped `pendingChanges()` all derive from
  it; typed getters (`gold`, `researchPoint`, …) are thin wrappers. Add an editable value =
  one row + a `Currency` case.
- **raiseIntField(inObjectAt:field:to:floor:)** — the one combinator behind the object-keyed
  "max a field" ops (merman village count, staff level, caught-fish grade). Inventory items
  (reference-DB tier map) and farm storage (array iteration) are intentional non-users.
- **ReferenceDB** — read-only SQLite over the shipped `reference.sqlite` (item names + tiers).
- **BackupStore** — per-save backup subfolders (`Backups/<folderToken>/`), listing, and
  atomic writes. **SaveGuard** — the pre-write "is the game running / file open?" gate.
- **SaveLocator** — finds save slots under the known nexon roots (`allSaves` / `newestSave`).

## App (`App/Sources/`)

- **SaveEditorModel** — the one `@Observable` coordination layer: load, edit, the bulk-op
  runner + undo stack (`mutateBulk`), backup/restore, discovery, search, raw view. Kept
  whole on purpose — its coordination carries the real safety protocol (guard → validate →
  in-memory backup → write). Deepen the seams it depends on rather than splitting it.
- **Currency** — UI metadata (label / icon / caption / max-button) for an editable scalar;
  its `rawValue` keys into `editableScalars`.
- **BulkAction** — the catalog describing every bulk "max/fill" op as data
  (`id · title · icon · accent · section · includeInMaxEverything · run`). The single source
  the model's `run(_:)` + named entry points, `maxEverything` (folds it), and the UI's
  `bulkRows` all derive from — so an op is defined in exactly one place.
