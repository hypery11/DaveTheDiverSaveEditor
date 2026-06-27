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
    var alert: AppAlert?

    // MARK: Backing state

    /// Live, editable document. `nil` until a save loads. Mutating it republishes to
    /// observers, so every `value(_:)` / `displayText(_:)` read re-renders on edit.
    private var document: SaveDocument?

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
        } catch {
            self.alert = AppAlert(
                id: UUID(),
                title: "Couldn't read save",
                message: "This file isn't a readable Dave the Diver save.",
                revealURL: nil
            )
        }
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
        guard let value = Int64(text) else { return }
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
