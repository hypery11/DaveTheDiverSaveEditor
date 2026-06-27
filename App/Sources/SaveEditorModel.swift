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
    var alert: AppAlert?
    /// Set to `true` by the ⌘S menu command; ContentView observes this to
    /// present the preview sheet, then resets it to `false`.
    var requestWrite: Bool = false

    // MARK: Backing state

    /// Live, editable document. `nil` until a save loads. Mutating it republishes to
    /// observers, so every `value(_:)` / `displayText(_:)` read re-renders on edit.
    private var document: SaveDocument?

    /// Cache for a lazily-resolved `ReferenceDB.bundled()` when none was injected.
    private var loadedReferenceDB: ReferenceDB?

    /// Currency values captured at load time — the Reset target and diff baseline.
    private var loadedValues: [Currency: Int64] = [:]

    // MARK: Injected collaborators (consumed by later tasks)

    private let referenceDB: ReferenceDB?
    private let fileManager: FileManager
    private let home: URL?

    init(referenceDB: ReferenceDB? = nil,
         fileManager: FileManager = .default,
         home: URL? = nil) {
        self.referenceDB = referenceDB
        self.fileManager = fileManager
        self.home = home
    }

    // MARK: Loading

    /// Decode + parse `data` into a `SaveDocument`. On success, replace state and
    /// snapshot the four currencies. On a parse failure, surface an `AppAlert` and
    /// leave any existing loaded state untouched.
    func load(data: Data, sourceURL: URL?) {
        do {
            let document = try SaveDocument.load(data)
            self.document = document
            self.loadedValues = [
                .gold:          document.gold,
                .bei:           document.bei,
                .artisansFlame: document.artisansFlame,
                .followerCount: document.followerCount,
            ]
            self.currentFileURL = sourceURL
            self.isLoaded = true
            self.alert = nil
            self.ingredientStatus = ""
            AppLog.io.info("Loaded save \(sourceURL?.lastPathComponent ?? "in-memory"): gold=\(value(.gold) ?? -1) bei=\(value(.bei) ?? -1) flame=\(value(.artisansFlame) ?? -1) followers=\(value(.followerCount) ?? -1)")
        } catch {
            AppLog.io.error("Failed to load \(sourceURL?.lastPathComponent ?? "in-memory"): \(error.localizedDescription)")
            self.alert = AppAlert(
                id: UUID(),
                title: "Couldn't read save",
                message: "This file isn't a readable Dave the Diver save.",
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

    func load(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            load(data: data, sourceURL: url)
        } catch {
            alert = AppAlert(
                id: UUID(),
                title: "Could Not Read Save",
                message: "Failed to read \(url.lastPathComponent): \(error.localizedDescription)",
                revealURL: nil
            )
        }
    }

    // MARK: - Ingredients

    private func resolvedReferenceDB() -> ReferenceDB? {
        if let referenceDB { return referenceDB }
        if let loadedReferenceDB { return loadedReferenceDB }
        do {
            let db = try ReferenceDB.bundled()
            loadedReferenceDB = db
            return db
        } catch {
            alert = AppAlert(
                id: UUID(),
                title: "Reference Data Error",
                message: "Could not load the bundled ingredient reference database: \(error.localizedDescription)",
                revealURL: nil
            )
            return nil
        }
    }

    func maxOwnIngredients() {
        guard document != nil, let ref = resolvedReferenceDB() else { return }
        document?.maxOwnedIngredients(using: ref)
        ingredientStatus = "Maxed owned ingredients."
        AppLog.model.info("Max-own ingredients → \(ingredientStatus)")
    }

    func maxAllIngredients() {
        guard document != nil, let ref = resolvedReferenceDB() else { return }
        document?.maxAllIngredients(using: ref)
        ingredientStatus = "Maxed all ingredients."
        AppLog.model.info("Max-all ingredients → \(ingredientStatus)")
    }

    // MARK: - Write

    @discardableResult
    func write() -> URL? {
        guard isLoaded, let url = currentFileURL, let document else { return nil }
        var backupURL: URL? = nil
        do {
            backupURL = try BackupStore.backup(original: url, bundleID: Self.bundleID, home: home)
            AppLog.io.notice("Backup written: \(backupURL!.path)")
            try BackupStore.writeAtomically(document.encoded(), to: url)
            AppLog.io.notice("Wrote save: \(url.lastPathComponent)")
            alert = AppAlert(
                id: UUID(),
                title: "Save Written",
                message: "Your changes were written to \(url.lastPathComponent). A timestamped backup was saved first.",
                revealURL: backupURL
            )
            return backupURL
        } catch {
            AppLog.io.error("Write failed: \(error.localizedDescription)")
            alert = AppAlert(
                id: UUID(),
                title: "Write Failed",
                message: "Could not write the save: \(error.localizedDescription)",
                revealURL: backupURL
            )
            return nil
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

    /// Apply the currency's "Set to Max" preset (`maxButtonValue`).
    func maximize(_ currency: Currency) {
        apply(currency, currency.maxButtonValue)
    }

    /// Restore the currency to its load-time value.
    func reset(_ currency: Currency) {
        guard let value = loadedValues[currency] else { return }
        apply(currency, value)
    }

    // MARK: Change preview

    /// `true` when the current document differs from its load-time snapshot.
    var hasChanges: Bool { !pendingChanges().isEmpty }

    /// Per-field `old -> new` diff over the four currency paths.
    func pendingChanges() -> [FieldChange] {
        document?.pendingChanges() ?? []
    }

    // MARK: Private helpers

    /// Route a value to the correct `SaveDocument` setter (which applies engine
    /// clamps). Copy-mutate-writeback so the `@Observable` store republishes.
    private func apply(_ currency: Currency, _ value: Int64) {
        guard var document else { return }
        switch currency {
        case .gold:          document.setGold(value)
        case .bei:           document.setBei(value)
        case .artisansFlame: document.setArtisansFlame(value)
        case .followerCount: document.setFollowerCount(value)
        }
        self.document = document
    }

    private static func read(_ currency: Currency, from document: SaveDocument) -> Int64 {
        switch currency {
        case .gold:          return document.gold
        case .bei:           return document.bei
        case .artisansFlame: return document.artisansFlame
        case .followerCount: return document.followerCount
        }
    }
}
