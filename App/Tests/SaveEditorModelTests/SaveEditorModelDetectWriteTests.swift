import Testing
import Foundation
@testable import DaveTheDiverSaveEditor
import DaveSaveCore

@MainActor
@Suite struct SaveEditorModelDetectWriteTests {

    // MARK: - Fixtures

    /// A valid, minimal save: four currency paths plus an empty `Ingredients`
    /// container (so Max-All has somewhere to inject). Encoded with the real codec.
    private func saveData(gold: Int64 = 100, includeIngredients: Bool = false) -> Data {
        let ingredients = includeIngredients ? ",\"Ingredients\":{}" : ""
        let json = "{\"PlayerInfo\":{\"m_Gold\":\(gold),\"m_Bei\":5,\"m_ChefFlame\":1}"
            + ",\"SNSInfo\":{\"m_Follow_Count\":7}\(ingredients)}"
        return SaveCodec.encode(json)
    }

    private func makeTempHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("davehome-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func model(home: URL) -> SaveEditorModel {
        SaveEditorModel(referenceDB: nil, fileManager: .default, home: home)
    }

    // MARK: - detectLatestSave / loadDetected

    @Test func detectFindsPlantedSaveAndLoadsIt() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }

        // Plant under a verified real root shape: …/com.nexon.dave/SteamSData/<digits>/
        let dir = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("com.nexon.dave", isDirectory: true)
            .appendingPathComponent("SteamSData", isDirectory: true)
            .appendingPathComponent("123456789", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("GameSave_0_GD.sav", isDirectory: false)
        try saveData().write(to: fileURL)

        let m = model(home: home)
        #expect(m.detected == nil)

        m.detectLatestSave()
        #expect(m.detected?.fileURL.path == fileURL.path)

        m.loadDetected()
        #expect(m.isLoaded)
        #expect(m.value(.gold) == 100)
        #expect(m.alert == nil)
    }

    // MARK: - load(url:) + write() round-trip with backup

    @Test func writeBacksUpOriginalThenPersistsEdit() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let saveDir = home.appendingPathComponent("save", isDirectory: true)
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        let fileURL = saveDir.appendingPathComponent("GameSave_0_GD.sav", isDirectory: false)
        try saveData(gold: 100).write(to: fileURL)

        let m = model(home: home)
        m.load(url: fileURL)
        #expect(m.isLoaded)
        #expect(m.value(.gold) == 100)

        m.applyText(.gold, "999")
        #expect(m.hasChanges)

        let backup = m.write()
        #expect(backup != nil)
        #expect(m.alert?.revealURL == backup)            // success alert carries the backup URL

        // A backup now exists in the per-bundle backup directory under the temp home.
        let backups = BackupStore.listBackups(bundleID: SaveEditorModel.bundleID, home: home)
        #expect(!backups.isEmpty)

        // The backup holds the ORIGINAL gold (taken before the overwrite)…
        let backupDoc = try SaveDocument.load(Data(contentsOf: try #require(backup)))
        #expect(backupDoc.gold == 100)

        // …and the on-disk save now reloads with the edited gold.
        let reloaded = try SaveDocument.load(Data(contentsOf: fileURL))
        #expect(reloaded.gold == 999)
    }

    @Test func writeWithoutLoadReturnsNil() {
        let m = model(home: FileManager.default.temporaryDirectory)
        #expect(m.write() == nil)
    }

    @Test func loadFromMissingFileSetsErrorAlert() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let m = model(home: home)
        m.load(url: home.appendingPathComponent("does-not-exist.sav", isDirectory: false))
        #expect(!m.isLoaded)
        #expect(m.alert != nil)
    }

    // MARK: - Ingredients (lazy ReferenceDB.bundled resolution + status)

    @Test func maxAllIngredientsResolvesBundledDBAndPersists() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let saveDir = home.appendingPathComponent("save", isDirectory: true)
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        let fileURL = saveDir.appendingPathComponent("GameSave_0_GD.sav", isDirectory: false)
        try saveData(includeIngredients: true).write(to: fileURL)

        let m = model(home: home)               // referenceDB: nil -> must lazily load the bundled DB
        m.load(url: fileURL)

        m.maxAllIngredients()
        #expect(m.ingredientStatus == "Maxed all ingredients.")
        #expect(m.alert == nil)                 // bundled reference DB resolved without error

        // The injection reached the live document and survives encode->write->decode.
        _ = m.write()
        let decoded = SaveCodec.decode(try Data(contentsOf: fileURL))
        #expect(decoded.contains("ingredientsID"))
    }

    @Test func maxOwnIngredientsSetsStatus() throws {
        let home = try makeTempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let m = model(home: home)
        m.load(data: saveData(includeIngredients: true), sourceURL: nil)

        m.maxOwnIngredients()
        #expect(m.ingredientStatus == "Maxed owned ingredients.")
        #expect(m.alert == nil)
    }
}
