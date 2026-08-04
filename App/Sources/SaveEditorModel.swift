import AppKit
import Foundation
import Observation
import DaveSaveCore

/// Owns every piece of save-editing logic; SwiftUI views are thin and bind to it.
/// Task 2 covers load + read + per-currency edit. Save discovery, writing/backup,
/// and the ingredient operations are layered onto this same type by later tasks.
@MainActor
@Observable
final class SaveEditorModel {

    /// Application bundle identifier (used by backup pathing in a later task).
    static let bundleID = "app.davethediver.saveeditor"

    // MARK: Observable UI state

    private(set) var isLoaded = false
    private(set) var currentFileURL: URL?
    private(set) var detected: SaveCandidate?
    private(set) var ingredientStatus: String = ""
    /// Latches `true` when a bulk ingredient/material op runs. Those ops mutate many
    /// nested fields the model never snapshots, so their effect cannot be diffed or
    /// reversed through the UI — a one-way latch is the honest representation, and it
    /// keeps the Write button live after a material-only edit (which `pendingChanges()`
    /// does not track). Currency and research-point edits are NOT latched here; they are
    /// diffed against the load-time snapshot in `hasChanges`, so a Reset can clear them.
    /// Reset to `false` on every load.
    private(set) var bulkEdited = false
    /// Human-readable log of bulk ops applied since load (for the write preview, which
    /// can't diff them). Cleared on load.
    private(set) var appliedBulkOps: [String] = []
    var alert: AppAlert?
    /// Set to `true` by the ⌘S menu command; ContentView observes this to
    /// present the preview sheet, then resets it to `false`.
    var requestWrite: Bool = false

    // MARK: Backing state

    /// Live, editable document. `nil` until a save loads. Mutating it republishes to
    /// observers, so every `value(_:)` / `displayText(_:)` read re-renders on edit.
    private var document: SaveDocument?

    /// Drives the support prompt. Set at launch and after every third successful write.
    /// Presented on *dismissal* of the write-success alert, never during the write itself —
    /// the confirmation sheet is the one modal a user must read to protect their save.
    var supportPrompt: SupportPromptKind?

    /// Whether Steam Cloud is holding a copy of the loaded save. Refreshed on every load —
    /// it is file I/O, so it must not be recomputed from a render path. Advisory only: it
    /// never blocks a write, because plenty of players legitimately have Cloud off or want
    /// to move the file themselves.
    private(set) var steamCloud: SteamCloudGuard.Status = .notSyncing

    /// Why the bundled reference database could not be opened, or nil when it is fine.
    /// Resolved once in `init`, never from a read path — see `resolvedReferenceDB()`.
    private(set) var referenceDBError: String?

    /// Currency values captured at load time — the Reset target and diff baseline.
    private var loadedValues: [Currency: Int64] = [:]

    // MARK: Injected collaborators (consumed by later tasks)

    private let referenceDB: ReferenceDB?
    private let fileManager: FileManager
    private let home: URL?

    /// Pre-write safety check (game-running / file-open). Defaults to always-safe so
    /// tests and SwiftUI previews never spawn `ps`/`lsof`; the app's composition root
    /// injects the real `SaveGuard.check`.
    private let safetyCheck: (URL) -> SaveGuard.Status

    init(referenceDB: ReferenceDB? = nil,
         fileManager: FileManager = .default,
         home: URL? = nil,
         safetyCheck: @escaping (URL) -> SaveGuard.Status = { _ in .safe }) {
        // Resolve the reference DB eagerly. It used to be looked up lazily from
        // `inventoryRows()`, which SwiftUI calls *inside* `body` — and the failure path
        // assigned `alert`, mutating observed state during render with a fresh UUID each
        // time, so a missing database re-invalidated the view forever. Resolving here
        // keeps every read path side-effect free.
        if let referenceDB {
            self.referenceDB = referenceDB
        } else {
            do {
                self.referenceDB = try ReferenceDB.bundled()
            } catch {
                self.referenceDB = nil
                self.referenceDBError = error.localizedDescription
                self.alert = AppAlert(
                    id: UUID(),
                    title: String(localized: "Reference Data Error"),
                    message: String(localized: "Could not load the bundled ingredient reference database: \(error.localizedDescription)"),
                    revealURL: nil
                )
            }
        }
        self.fileManager = fileManager
        self.home = home
        self.safetyCheck = safetyCheck
    }

    // MARK: Loading

    /// Decode + parse `data` into a `SaveDocument`. On success, replace state and
    /// snapshot the four currencies. On a parse failure, surface an `AppAlert` and
    /// leave any existing loaded state untouched.
    func load(data: Data, sourceURL: URL?) {
        do {
            let document = try SaveDocument.load(data)
            self.document = document
            // Snapshot every currency generically from the engine table — no per-case
            // dictionary literal to keep in sync (a missing key used to silently break Reset).
            self.loadedValues = Dictionary(uniqueKeysWithValues:
                Currency.allCases.map { ($0, document.intValue(forID: $0.rawValue)) })
            self.currentFileURL = sourceURL
            self.steamCloud = sourceURL.map { SteamCloudGuard.check(saveURL: $0, home: home) } ?? .notSyncing
            self.isLoaded = true
            self.alert = nil
            self.ingredientStatus = ""
            self.bulkEdited = false
            self.appliedBulkOps = []
            self.undoStack = []
            self.redoStack = []

            AppLog.io.info("Loaded save \(sourceURL?.lastPathComponent ?? "in-memory"): gold=\(value(.gold) ?? -1) bei=\(value(.bei) ?? -1) flame=\(value(.artisansFlame) ?? -1) followers=\(value(.followerCount) ?? -1)")
        } catch {
            AppLog.io.error("Failed to load \(sourceURL?.lastPathComponent ?? "in-memory"): \(error.localizedDescription)")
            self.alert = AppAlert(
                id: UUID(),
                title: String(localized: "Couldn't read save"),
                message: String(localized: "This file isn't a readable Dave the Diver save."),
                revealURL: nil
            )
        }
    }

    // MARK: - Save discovery

    func detectLatestSave() {
        detected = SaveLocator.newestSave(fileManager: fileManager, home: home)
        AppLog.io.info("Detected latest save: \(detected?.fileURL.path ?? "none found")")
    }

    func loadDetected() {
        guard let candidate = detected else { return }
        load(url: candidate.fileURL)
    }

    /// Every save slot found on disk (newest first) — for the slot picker.
    func availableSaves() -> [SaveCandidate] {
        SaveLocator.allSaves(fileManager: fileManager, home: home)
    }

    func load(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            load(data: data, sourceURL: url)
        } catch {
            alert = AppAlert(
                id: UUID(),
                title: String(localized: "Could Not Read Save"),
                message: String(localized: "Failed to read \(url.lastPathComponent): \(error.localizedDescription)"),
                revealURL: nil
            )
        }
    }

    // MARK: - Ingredients

    /// The reference database, or nil when it failed to open. Pure: resolution and error
    /// reporting both happen in `init`, because this is called from `inventoryRows()` on
    /// SwiftUI's render path and must not mutate observed state.
    private func resolvedReferenceDB() -> ReferenceDB? {
        referenceDB
    }

    /// Show the launch prompt.
    func offerSupportAtLaunch() {
        guard SupportAsk.isDueAtLaunch else { return }
        supportPrompt = .launch
    }

    /// Count the write that just succeeded, and prompt on every third one. Called when the
    /// write-success alert is dismissed, so it never lands on top of it.
    func registerWriteForSupportPrompt() {
        if let total = SupportAsk.registerWriteAndCheck() {
            supportPrompt = .afterWrites(total)
        }
    }

    // MARK: - Undo / redo

    /// Everything an edit can change, captured so undo restores state exactly rather
    /// than reconstructing it. `appliedBulkOps` and `bulkEdited` are part of the snapshot
    /// because the old `removeLast()` guesswork could not express "this step was a
    /// currency edit, so the bulk log is untouched".
    private struct EditState {
        let document: SaveDocument
        let bulkEdited: Bool
        let appliedBulkOps: [String]
    }

    /// One reversible step: the state *before* it, plus what to call it in the Edit menu.
    private struct UndoStep {
        let before: EditState
        let label: String
        /// Non-nil for currency edits (the currency's id). Consecutive steps sharing a key
        /// within `coalesceWindow` collapse into one, so holding `+1k` is a single undo.
        let coalesceKey: String?
        let at: Date
    }

    /// Whole-document snapshots, so the depth is capped rather than unbounded.
    private static let undoLimit = 50
    private static let coalesceWindow: TimeInterval = 1.0

    private var undoStack: [UndoStep] = []
    private var redoStack: [UndoStep] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    /// Names the step ⌘Z would revert, for the Edit menu's "Undo <thing>".
    var undoLabel: String? { undoStack.last?.label }
    var redoLabel: String? { redoStack.last?.label }

    private var currentEditState: EditState? {
        document.map { EditState(document: $0, bulkEdited: bulkEdited, appliedBulkOps: appliedBulkOps) }
    }

    private func restore(_ state: EditState) {
        document = state.document
        bulkEdited = state.bulkEdited
        appliedBulkOps = state.appliedBulkOps
    }

    /// Push an undo step for an edit that is about to happen. Any new edit invalidates
    /// the redo stack, exactly as a text editor does.
    private func pushUndo(label: String, coalesceKey: String? = nil) {
        guard let before = currentEditState else { return }
        redoStack.removeAll()
        if let key = coalesceKey, let top = undoStack.last, top.coalesceKey == key,
           Date().timeIntervalSince(top.at) < Self.coalesceWindow {
            // Same row, still in the burst — keep the older "before" so undo jumps back
            // past the whole run of clicks instead of unwinding them one at a time.
            return
        }
        undoStack.append(UndoStep(before: before, label: label,
                                  coalesceKey: coalesceKey, at: Date()))
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
    }

    /// Snapshot the doc, run `body` (returns a status string, or nil to abort with no
    /// change), write back, and record it as one undoable step.
    private func mutateBulk(_ body: (inout SaveDocument, ReferenceDB?) -> String?) {
        guard var doc = document, let before = currentEditState else { return }
        guard let status = body(&doc, resolvedReferenceDB()) else { return }
        redoStack.removeAll()
        undoStack.append(UndoStep(before: before, label: status,
                                  coalesceKey: nil, at: Date()))
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
        document = doc
        recordBulk(status)
    }

    /// Revert the most recent edit — currency or bulk. Previously this restored a
    /// whole-document snapshot taken before a *bulk* op, which silently threw away any
    /// currency edits made afterwards; currency edits were not undoable at all.
    func undo() {
        guard let current = currentEditState, let step = undoStack.popLast() else { return }
        redoStack.append(UndoStep(before: current, label: step.label,
                                  coalesceKey: nil, at: Date()))
        restore(step.before)
        ingredientStatus = String(localized: "Undid last edit.")
    }

    func redo() {
        guard let current = currentEditState, let step = redoStack.popLast() else { return }
        undoStack.append(UndoStep(before: current, label: step.label,
                                  coalesceKey: nil, at: Date()))
        restore(step.before)
        ingredientStatus = String(localized: "Redid last edit.")
    }

    /// Record a bulk op's result: marks dirty, sets the shared status, and logs it in
    /// `appliedBulkOps` so the write preview can show what will be written.
    private func recordBulk(_ status: String) {
        bulkEdited = true
        ingredientStatus = status
        appliedBulkOps.append(status)
        AppLog.model.info("bulk → \(status)")
    }

    // MARK: - Bulk operations (each defined once in BulkAction.catalog)

    /// Run one bulk action through the undo-tracking `mutateBulk` combinator.
    func run(_ action: BulkAction) {
        mutateBulk { doc, ref in action.run(&doc, ref) }
    }

    // Named entry points, kept for readable call sites + tests; each just runs its
    // catalog action, so the op is defined in exactly one place (BulkAction.catalog).
    func maxOwnIngredients()    { run(.with(id: "maxOwn")) }
    func maxAllIngredients()    { run(.with(id: "maxAll")) }
    func maxBranchIngredients() { run(.with(id: "maxBranch")) }
    func maxStaff()             { run(.with(id: "maxStaff")) }
    func maxInventoryItems()    { run(.with(id: "maxInventory")) }
    func maxCraftMaterials()    { run(.with(id: "maxCraft")) }
    func maxMermanInventory()   { run(.with(id: "maxMerman")) }
    func maxSeeds()             { run(.with(id: "maxSeeds")) }
    func maxFishGrades()        { run(.with(id: "maxFish")) }

    /// One-click convenience: run every catalog action flagged `includeInRunAll`, in one
    /// undo step. Correct-by-construction — it IS the catalog, so it can't drift from the
    /// buttons. (`inout doc` can't be captured in a closure, hence the for-loop.)
    ///
    /// Named "fills" deliberately: it touches no `Currency` at all. As "Max Everything" it
    /// implied maxed gold, which a user pressing it would reasonably expect and never get.
    func runAllFills() {
        mutateBulk { doc, ref in
            var ran: [String] = []
            for action in BulkAction.catalog where action.includeInRunAll {
                // List each fill that actually ran (shows in the write preview), so the
                // summary stays informative rather than just a count.
                if action.run(&doc, ref) != nil {
                    ran.append(action.buttonTitle)
                }
            }
            // Both of these used to be plain Swift string literals, so the status line for
            // the app's headline action was English in all four locales. The old code also
            // stripped a literal "Max " prefix off each localized button title, which only
            // ever matched in English.
            guard !ran.isEmpty else { return String(localized: "Nothing to fill.") }
            return String(localized: "Ran every fill — \(ran.joined(separator: ", ")).")
        }
    }

    /// Add or set a specific inventory item by id and count. Resolves the item's name for
    /// feedback; a missing `InventoryItemSlot` container is reported (and not undoable).
    func addInventoryItem(itemID: Int, count: Int) {
        guard let original = document, let before = currentEditState else { return }
        var doc = original
        guard doc.setInventoryItem(itemID: itemID, count: count) else {
            ingredientStatus = String(localized: "Couldn't set item \(String(itemID)) (no inventory container).")
            return
        }
        redoStack.removeAll()
        undoStack.append(UndoStep(before: before,
                                  label: resolvedReferenceDB()?.itemName(id: itemID) ?? String(localized: "item"),
                                  coalesceKey: nil, at: Date()))
        if undoStack.count > Self.undoLimit { undoStack.removeFirst() }
        document = doc
        let name = resolvedReferenceDB()?.itemName(id: itemID) ?? String(localized: "item")
        recordBulk(String(localized: "Set \(name) (\(String(itemID))) → \(count)."))
    }

    // MARK: - Per-item browse / search

    /// A named inventory row for the browse view.
    struct InventoryRow: Identifiable, Equatable {
        let id: Int          // itemID
        let name: String
        let count: Int
    }

    /// The save's inventory slots, name-resolved and sorted by id.
    func inventoryRows() -> [InventoryRow] {
        guard let document, let ref = resolvedReferenceDB() else { return [] }
        return document.inventoryItems().map { slot in
            InventoryRow(id: slot.itemID, name: ref.itemName(id: slot.itemID) ?? "#\(slot.itemID)", count: slot.count)
        }
    }

    /// Search the reference item table by name (for the Advanced item picker).
    func searchItems(_ query: String) -> [ItemMatch] {
        resolvedReferenceDB()?.searchItems(query) ?? []
    }

    /// Readable name for an item id, or a fallback.
    func itemName(for id: Int) -> String {
        resolvedReferenceDB()?.itemName(id: id) ?? String(localized: "item \(String(id))")
    }

    /// The whole loaded save as indented, order-preserving JSON — for the read-only
    /// Raw inspector. Empty when nothing is loaded.
    func rawJSON() -> String {
        document?.prettyJSON() ?? ""
    }

    /// A localized reason the write/restore is blocked. `SaveGuard.Status.blockReason` is
    /// deliberately English-only — it is shared with `dtdcli`, which is English by design —
    /// so the app builds its own copy here. Without this the alert showed a localized
    /// title over an English body.
    private func localizedBlockReason(_ status: SaveGuard.Status) -> String? {
        if status.gameRunning {
            return String(localized: "Dave the Diver is still running. Quit the game fully (⌘Q) before writing — a running game overwrites your edits on its next save.")
        }
        if status.fileOpen {
            return String(localized: "The save file is currently open by another process. If you just quit the game, wait a moment and try again.")
        }
        return nil
    }

    // MARK: - Write

    @discardableResult
    func write() -> URL? {
        guard isLoaded, let url = currentFileURL, let document else { return nil }
        // Refuse to write while the game is running or the file is held open — a running
        // game would overwrite the edit on its next save.
        if let reason = localizedBlockReason(safetyCheck(url)) {
            AppLog.io.error("Write blocked by safety check: \(reason)")
            alert = AppAlert(
                id: UUID(),
                title: String(localized: "Can't Write Yet"),
                message: reason,
                revealURL: nil
            )
            return nil
        }
        var backupURL: URL? = nil
        do {
            backupURL = try BackupStore.backup(original: url, bundleID: Self.bundleID, home: home)
            AppLog.io.notice("Backup written: \(backupURL!.path)")
            let written = document.encoded()
            try BackupStore.writeAtomically(written, to: url)

            // Read the file back and re-decode it before claiming success. `dtdcli` has
            // always done this; the app used to report "written" on the strength of
            // `writeAtomically` not throwing, which cannot catch a truncated or
            // mis-encoded write. This only proves the bytes landed — it says nothing
            // about the game later recomputing a value, which is out of scope.
            let reread = try Data(contentsOf: url)
            guard reread == written, let _ = try? SaveDocument.load(reread) else {
                AppLog.io.error("Post-write verification failed for \(url.lastPathComponent)")
                alert = AppAlert(
                    id: UUID(),
                    title: String(localized: "Write Failed"),
                    message: String(localized: "The save was written but did not read back correctly. Your original is in the backup — restore it before playing."),
                    revealURL: backupURL
                )
                return nil
            }
            AppLog.io.notice("Wrote save: \(url.lastPathComponent) (verified \(written.count) bytes)")

            // Re-baseline: the file on disk now IS the document, so the editor must stop
            // reporting unsaved work. Without this, Save stayed enabled after a
            // successful write, a second Save wrote a duplicate backup of identical
            // bytes, and switching slots warned about discarding changes that were
            // already saved. `load(data:)` also clears the undo stacks and `alert`, so
            // the success alert has to be assigned *after* it.
            load(data: written, sourceURL: url)
            alert = AppAlert(
                id: UUID(),
                kind: .writeSucceeded,
                title: String(localized: "Save Written"),
                message: String(localized: "Your changes were written to \(url.lastPathComponent). A timestamped backup was saved first."),
                revealURL: backupURL
            )
            return backupURL
        } catch {
            AppLog.io.error("Write failed: \(error.localizedDescription)")
            alert = AppAlert(
                id: UUID(),
                title: String(localized: "Write Failed"),
                message: String(localized: "Could not write the save: \(error.localizedDescription)"),
                revealURL: backupURL
            )
            return nil
        }
    }

    // MARK: - Backups

    /// Timestamped backups for the currently-loaded save (newest first). Scoped to this
    /// exact save by `BackupStore`'s per-save subfolder, so identically-named saves in
    /// other Steam-id folders can never surface here.
    func availableBackups() -> [URL] {
        guard let url = currentFileURL else { return [] }
        return BackupStore.listBackups(for: url, bundleID: Self.bundleID, home: home)
    }

    /// Overwrite the live save with a chosen backup. Mirrors `write()`'s safety flow, and
    /// is careful in a few ways the reviewer flagged: it (1) refuses while the game is
    /// running / the file is open; (2) VALIDATES the backup parses BEFORE touching the live
    /// file (so a corrupt backup can never be written + falsely reported as success);
    /// (3) backs up the CURRENT in-memory document — including unsaved edits — so the
    /// restore is genuinely reversible; then reloads so the UI reflects the restored save.
    func restore(from backupURL: URL) {
        guard isLoaded, let url = currentFileURL, let document else { return }
        if let reason = localizedBlockReason(safetyCheck(url)) {
            AppLog.io.error("Restore blocked by safety check: \(reason)")
            alert = AppAlert(id: UUID(), title: String(localized: "Can't Restore Yet"), message: reason, revealURL: nil)
            return
        }
        do {
            let data = try Data(contentsOf: backupURL)
            _ = try SaveDocument.load(data)                    // throws on a corrupt backup — before any write
            let safetyBackup = try BackupStore.backupData(document.encoded(), forSaveNamed: url,
                                                          bundleID: Self.bundleID, home: home)
            try BackupStore.writeAtomically(data, to: url)
            AppLog.io.notice("Restored backup \(backupURL.lastPathComponent) onto \(url.lastPathComponent)")
            load(data: data, sourceURL: url)                   // reload so values / dirty-state are fresh
            alert = AppAlert(
                id: UUID(),
                title: String(localized: "Backup Restored"),
                message: String(localized: "Restored \(backupURL.lastPathComponent). Your previous state was saved as \(safetyBackup.lastPathComponent) — reveal it to undo."),
                revealURL: safetyBackup
            )
        } catch {
            AppLog.io.error("Restore failed: \(error.localizedDescription)")
            alert = AppAlert(id: UUID(), title: String(localized: "Restore Failed"),
                             message: String(localized: "Could not restore the backup: \(error.localizedDescription)"), revealURL: nil)
        }
    }

    // MARK: - Finder

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: Reading

    /// Current value of `currency`, or `nil` before a save loads.
    func value(_ currency: Currency) -> Int64? {
        guard let document else { return nil }
        return Self.read(currency, from: document)
    }

    /// Value of `currency` at load time (Reset / diff baseline), or `nil`.
    func loadedValue(_ currency: Currency) -> Int64? {
        loadedValues[currency]
    }

    /// Text for the currency's TextField: empty before load, else the integer.
    func displayText(_ currency: Currency) -> String {
        guard let value = value(currency) else { return "" }
        return String(value)
    }

    // MARK: Editing

    /// Parse `text` as an `Int64` and write it via the matching setter. Empty or
    /// non-numeric input is a deliberate no-op (the field keeps its prior value).
    func applyText(_ currency: Currency, _ text: String) {
        guard let value = Int64(text), value >= 0 else { return }
        apply(currency, value)
    }

    /// Set an already-parsed exact value. The view parses once (via `CountInput`, shared
    /// with the button's enabled test) instead of handing back a string for `applyText` to
    /// re-parse with different rules.
    func setExact(_ currency: Currency, _ value: Int64) {
        guard value >= 0 else { return }
        apply(currency, value)
    }

    /// Apply the currency's "Set to Max" preset (`maxButtonValue`).
    func maximize(_ currency: Currency) {
        apply(currency, currency.maxButtonValue)
    }

    /// Restore the currency to its load-time value.
    func reset(_ currency: Currency) {
        guard let value = loadedValues[currency] else { return }
        apply(currency, value)
    }

    /// Add `delta` to a value, clamped at 0 (and re-clamped to the setter's upper
    /// bound). Routes through the same `apply` path as exact entry, so dirty-tracking
    /// and engine clamps are unchanged. Powers the ±10/±100/±1000 buttons.
    func adjust(_ currency: Currency, by delta: Int64) {
        guard let current = value(currency) else { return }
        let next = max(0, current &+ delta)   // overflow-safe; setter re-clamps the top
        apply(currency, next)
    }

    // MARK: Change preview

    /// `true` when the current document differs from its load-time snapshot. Three
    /// sources, each independently reversible to "no change":
    /// - every editable scalar (gold/bei/flame/follower/research/trust/fake), diffed by
    ///   `pendingChanges()` — all live in the engine's `editableScalars` table now;
    /// - bulk ingredient/material ops, which latch `bulkEdited` (not individually
    ///   reversible, so they stay dirty until the next load).
    var hasChanges: Bool {
        bulkEdited || !pendingChanges().isEmpty
    }

    /// Per-field `old -> new` diff over every editable scalar (drives the write preview).
    func pendingChanges() -> [FieldChange] {
        document?.pendingChanges() ?? []
    }

    // MARK: Private helpers

    /// Route a value to the engine's clamped setter via the shared `editableScalars`
    /// table (`Currency.rawValue` is the table id). Copy-mutate-writeback so the
    /// `@Observable` store republishes. No dirty latch: currencies are diffed by
    /// `pendingChanges()`, so an edit followed by Reset correctly reads as clean.
    private func apply(_ currency: Currency, _ value: Int64) {
        guard var document else { return }
        guard Self.read(currency, from: document) != value else { return }   // no-op, nothing to undo
        pushUndo(label: currency.label, coalesceKey: currency.rawValue)
        document.setInt(value, forID: currency.rawValue)
        self.document = document
    }

    private static func read(_ currency: Currency, from document: SaveDocument) -> Int64 {
        document.intValue(forID: currency.rawValue)
    }
}
