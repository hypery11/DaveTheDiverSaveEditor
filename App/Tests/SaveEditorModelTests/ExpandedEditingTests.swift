import Testing
import Foundation
import DaveSaveCore
@testable import DaveTheDiverSaveEditor

/// Covers the post-v1 editing surface wired into the model: research point (as a
/// fifth `Currency`), and the branch / inventory / merman bulk material ops. The
/// research-point and Write-gating tests assert the model's UI state machine; the
/// branch test additionally round-trips through write+decode to prove a real
/// mutation reaches disk. The value-level algorithms live in DaveSaveCore's own tests.
@MainActor
@Suite struct ExpandedEditingTests {

    /// A save touching every expanded surface. `1021006` is a confirmed non-aberration
    /// tier-6666 ingredient in the bundled reference DB, so the branch op truly raises it.
    private static let fixtureJSON = #"""
    {"PlayerInfo":{"m_Gold":100,"m_Bei":5,"m_ChefFlame":1,"m_researchPoint":42},"SNSInfo":{"m_Follow_Count":7},"Ingredients":{"1021006":{"ingredientsID":1021006,"count":10,"branchCount":2}},"InventoryItemSlot":{"0":{"itemID":9999999,"totalCount":3}},"MermanVillInventory":{"0":{"count":5}}}
    """#

    /// In-memory model (explicit bundled DB) for the state-machine tests.
    private func loadedModel() throws -> SaveEditorModel {
        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled())
        model.load(data: SaveCodec.encode(Self.fixtureJSON), sourceURL: nil)
        return model
    }

    // MARK: Research point (rides the Currency machinery)

    @Test func loadsResearchPoint() throws {
        let model = try loadedModel()
        #expect(model.value(.researchPoint) == 42)
        #expect(model.loadedValue(.researchPoint) == 42)
        #expect(model.displayText(.researchPoint) == "42")
        #expect(model.hasChanges == false)
    }

    @Test func editingResearchPointEnablesWrite() throws {
        let model = try loadedModel()
        model.applyText(.researchPoint, "5000")
        #expect(model.value(.researchPoint) == 5000)
        #expect(model.hasChanges)            // diffed against the load-time snapshot
    }

    @Test func maximizeResearchPointClampsToButtonValue() throws {
        let model = try loadedModel()
        model.maximize(.researchPoint)
        #expect(model.value(.researchPoint) == 999_999_999)
        #expect(model.hasChanges)
    }

    /// Editing research point and then resetting it back to the loaded value must read
    /// as clean — research dirtiness is a diff, not a one-way latch.
    @Test func researchPointMaximizeThenResetIsClean() throws {
        let model = try loadedModel()
        model.maximize(.researchPoint)
        #expect(model.hasChanges)
        model.reset(.researchPoint)
        #expect(model.value(.researchPoint) == 42)
        #expect(model.hasChanges == false)
    }

    // MARK: Material bulk ops — status + dirty wiring (real mutations)

    @Test func maxInventorySetsStatusAndDirties() throws {
        let model = try loadedModel()
        model.maxInventoryItems()            // itemID 9999999, totalCount 3 -> 999
        #expect(model.ingredientStatus == "Maxed inventory items (1 slots).")
        #expect(model.hasChanges)
        #expect(model.alert == nil)
    }

    @Test func maxMermanSetsStatusAndDirties() throws {
        let model = try loadedModel()
        model.maxMermanInventory()           // count 5 -> 999
        #expect(model.ingredientStatus == "Maxed merman village inventory (1 slots).")
        #expect(model.hasChanges)
    }

    /// Branch op routed model -> engine -> write -> disk, asserting the persisted bytes.
    @Test func maxBranchPersistsBranchCountAndSetsStatus() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("dtdexp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let fileURL = home.appendingPathComponent("GameSave_0_GD.sav", isDirectory: false)
        try SaveCodec.encode(Self.fixtureJSON).write(to: fileURL)

        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled(), home: home)
        model.load(url: fileURL)
        model.maxBranchIngredients()
        #expect(model.ingredientStatus == "Maxed branch (second store) ingredients.")
        #expect(model.hasChanges)
        #expect(model.write() != nil)

        let decoded = SaveCodec.decode(try Data(contentsOf: fileURL))
        // branchCount raised 2 -> 6666; main-store count (10) untouched.
        #expect(decoded.contains(#""ingredientsID":1021006,"count":10,"branchCount":6666"#))
    }

    // MARK: The Write-gating fix

    /// A material-only edit changes no currency, so `pendingChanges()` stays empty —
    /// yet the Write button must enable. This is the regression `bulkEdited` fixes.
    @Test func materialOnlyEditEnablesWriteWithoutCurrencyChange() throws {
        let model = try loadedModel()
        #expect(model.hasChanges == false)
        model.maxMermanInventory()
        #expect(model.pendingChanges().isEmpty)   // no currency moved
        #expect(model.hasChanges)                  // …but Write is enabled
    }

    // MARK: Seeds, craft materials, and the add-item override

    @Test func maxSeedsRaisesStorageAndDirties() throws {
        let json = #"{"Farm":{"Storage":[{"ID":11070003,"Count":89,"Value":0,"Name":null,"IsNew":false}]}}"#
        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled())
        model.load(data: SaveCodec.encode(json), sourceURL: nil)
        model.maxSeeds()
        #expect(model.ingredientStatus == "Maxed farm seeds / produce (1 stacks).")
        #expect(model.hasChanges)
    }

    @Test func maxCraftMaterialsInjectsAndDirties() throws {
        // Bundled DB has DREDGE craft materials; DLC installed so they inject.
        let json = #"{"GameInfo":{"installedDLCs":[14252001]},"InventoryItemSlot":{}}"#
        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled())
        model.load(data: SaveCodec.encode(json), sourceURL: nil)
        model.maxCraftMaterials()
        #expect(model.ingredientStatus.hasPrefix("Maxed craft materials"))
        #expect(model.hasChanges)
        #expect(model.alert == nil)
    }

    @Test func addInventoryItemSetsStatusAndDirties() throws {
        let json = #"{"InventoryItemSlot":{}}"#
        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled())
        model.load(data: SaveCodec.encode(json), sourceURL: nil)
        model.addInventoryItem(itemID: 1014980, count: 99)
        #expect(model.ingredientStatus == "Set item 1014980 = 99.")
        #expect(model.hasChanges)
    }

    @Test func addInventoryItemWithoutContainerReportsAndStaysClean() throws {
        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled())
        model.load(data: SaveCodec.encode(#"{"PlayerInfo":{"m_Gold":1}}"#), sourceURL: nil)
        model.addInventoryItem(itemID: 1014980, count: 99)
        #expect(model.ingredientStatus.contains("no inventory container"))
        #expect(model.hasChanges == false)
    }

    // MARK: Pre-write safety guard

    /// When the safety check reports the game is running, `write()` must refuse, surface
    /// an alert, and leave the file byte-for-byte unchanged.
    @Test func writeIsBlockedWhenGuardReportsUnsafe() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("dtdguard-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let fileURL = home.appendingPathComponent("GameSave_0_GD.sav", isDirectory: false)
        let original = SaveCodec.encode(Self.fixtureJSON)
        try original.write(to: fileURL)

        let model = SaveEditorModel(
            referenceDB: try ReferenceDB.bundled(),
            home: home,
            safetyCheck: { _ in SaveGuard.Status(gameRunning: true, fileOpen: false) }
        )
        model.load(url: fileURL)
        model.maxMermanInventory()                 // make it dirty so write has something to do
        let result = model.write()
        #expect(result == nil)                      // blocked
        #expect(model.alert?.title == "Can't Write Yet")
        #expect(try Data(contentsOf: fileURL) == original)   // file untouched
    }
}
