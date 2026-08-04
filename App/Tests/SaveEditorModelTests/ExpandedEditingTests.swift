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
    {"PlayerInfo":{"m_Gold":100,"m_Bei":5,"m_ChefFlame":1,"m_researchPoint":42,"m_trustPoint":100,"m_FakePoint":100},"SNSInfo":{"m_Follow_Count":7},"Ingredients":{"1021006":{"ingredientsID":1021006,"count":10,"branchCount":2}},"InventoryItemSlot":{"0":{"itemID":9999999,"totalCount":3}},"MermanVillInventory":{"0":{"count":5}}}
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

    @Test func researchPointChangeShowsInPreviewDiff() throws {
        let model = try loadedModel()
        #expect(model.pendingChanges().isEmpty)
        model.applyText(.researchPoint, "5000")
        // The write preview lists research point too (so it never renders blank).
        #expect(model.pendingChanges().contains { $0.path == "PlayerInfo.m_researchPoint" && $0.newValue == "5000" })
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

    // MARK: Trust / Fake points (ride the currency machinery via editableScalars)

    @Test func trustAndFakePointsLoadEditDiffReset() throws {
        let model = try loadedModel()
        #expect(model.value(.trustPoint) == 100)
        #expect(model.value(.fakePoint) == 100)

        model.applyText(.trustPoint, "9999")
        #expect(model.value(.trustPoint) == 9999)
        #expect(model.hasChanges)                                        // diffed via editableScalars
        #expect(model.pendingChanges().contains { $0.path == "PlayerInfo.m_trustPoint" && $0.newValue == "9999" })

        model.reset(.trustPoint)
        #expect(model.value(.trustPoint) == 100)
        #expect(model.hasChanges == false)                               // reset clears it
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
        #expect(model.ingredientStatus == "Maxed Sea People Village storage (1 slots).")
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
        #expect(model.ingredientStatus == "Maxed branch ingredients (skips aberration fish).")
        #expect(model.hasChanges)
        #expect(model.write() != nil)

        let decoded = SaveCodec.decode(try Data(contentsOf: fileURL))
        // branchCount raised 2 -> 6666; main-store count (10) untouched.
        #expect(decoded.contains(#""ingredientsID":1021006,"count":10,"branchCount":6666"#))
    }

    /// After a successful write the file on disk *is* the document, so the editor must
    /// stop reporting unsaved work. It used to stay dirty forever: Save stayed enabled, a
    /// second Save wrote a duplicate backup of identical bytes, and switching slots
    /// warned about discarding changes that had already been saved.
    @Test func successfulWriteClearsTheDirtyState() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("dtdrebase-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let fileURL = home.appendingPathComponent("GameSave_0_GD.sav", isDirectory: false)
        try SaveCodec.encode(Self.fixtureJSON).write(to: fileURL)

        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled(), home: home)
        model.load(url: fileURL)
        model.applyText(.gold, "4242")
        model.maxMermanInventory()
        #expect(model.hasChanges)

        #expect(model.write() != nil)
        #expect(model.hasChanges == false)          // re-baselined against what we wrote
        #expect(model.canUndo == false)             // and the undo history starts fresh
        #expect(model.pendingChanges().isEmpty)
        #expect(model.value(.gold) == 4242)         // the edit is still there, just saved
        #expect(model.alert?.title == "Save Written")   // survives load(data:) clearing it
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
        #expect(model.ingredientStatus == "Set Dredge ResearchPart (1014980) → 99.")
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

    // MARK: Undo / redo

    @Test func undoRevertsLastBulkAndClears() throws {
        let model = try loadedModel()
        #expect(model.canUndo == false)
        model.maxMermanInventory()
        #expect(model.canUndo)
        #expect(model.hasChanges)
        model.undo()
        #expect(model.canUndo == false)
        #expect(model.hasChanges == false)   // reverted to the clean load state
    }

    /// Currency edits used to push nothing onto the undo stack, so ⌘Z / the undo button
    /// could not reach them at all — the only escape was per-row Reset.
    @Test func currencyEditsAreUndoable() throws {
        let model = try loadedModel()
        model.applyText(.gold, "555")
        #expect(model.value(.gold) == 555)
        #expect(model.canUndo)
        model.undo()
        #expect(model.value(.gold) == 100)          // the fixture's load-time value
        #expect(model.hasChanges == false)
    }

    /// The bug: `undoLastBulk` restored a whole-document snapshot taken *before* the bulk
    /// op, so any currency edit made afterwards was silently discarded — the opposite of
    /// what the code's own comment claimed.
    @Test func undoingABulkOpKeepsLaterCurrencyEdits() throws {
        let model = try loadedModel()
        model.maxMermanInventory()
        model.applyText(.gold, "12345")            // after the bulk op

        model.undo()                                // must undo ONLY the gold edit
        #expect(model.value(.gold) == 100)
        // The discriminating assertion: the bulk op is still applied, so the document is
        // still dirty and there is still a step to undo. The old code collapsed both
        // changes into this single undo, leaving a clean document and an empty stack.
        #expect(model.hasChanges)
        #expect(model.canUndo)

        model.undo()                                // now the bulk op
        #expect(model.hasChanges == false)
        #expect(model.canUndo == false)
    }

    /// Holding `+1k` must not bury the previous state under a hundred undo steps.
    @Test func rapidSameCurrencyEditsCoalesceIntoOneStep() throws {
        let model = try loadedModel()
        for _ in 0..<10 { model.adjust(.gold, by: 10) }
        #expect(model.value(.gold) == 200)
        model.undo()
        #expect(model.value(.gold) == 100)          // one step back to before the burst
        #expect(model.canUndo == false)
    }

    @Test func redoReappliesAnUndoneEdit() throws {
        let model = try loadedModel()
        model.applyText(.gold, "777")
        model.undo()
        #expect(model.canRedo)
        model.redo()
        #expect(model.value(.gold) == 777)
        #expect(model.canRedo == false)
    }

    /// A fresh edit after an undo invalidates redo, as in any text editor.
    @Test func newEditClearsRedoStack() throws {
        let model = try loadedModel()
        model.applyText(.gold, "777")
        model.undo()
        #expect(model.canRedo)
        model.applyText(.bei, "9")
        #expect(model.canRedo == false)
    }

    // MARK: Bulk-action catalog

    @Test func runAllFillsRunsFullCatalogInOneUndoStep() throws {
        let model = try loadedModel()
        #expect(model.hasChanges == false)
        model.runAllFills()
        #expect(model.hasChanges)                                   // it mutated
        #expect(model.ingredientStatus.hasPrefix("Ran every fill"))
        #expect(model.canUndo)                                  // exactly one undo step
        model.undo()
        #expect(model.hasChanges == false)                          // fully reversible
    }

    @Test func bulkCatalogIsConsistent() {
        let ids = BulkAction.catalog.map(\.id)
        #expect(Set(ids).count == ids.count)                        // unique ids
        // Run All Fills runs every action except "own" (superseded by "all").
        #expect(BulkAction.catalog.filter { !$0.includeInRunAll }.map(\.id) == ["maxOwn"])
        // Every named model entry point resolves to a catalog id (no orphans).
        for id in ["maxOwn","maxAll","maxBranch","maxStaff","maxInventory","maxCraft","maxMerman","maxSeeds","maxFish"] {
            #expect(BulkAction.catalog.contains { $0.id == id })
        }
    }

    // MARK: Backup restore

    private func tempHome() throws -> URL {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("dtdrestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        return home
    }

    @Test func restoreRefusesCorruptBackupAndLeavesLiveFileUntouched() throws {
        let home = try tempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let fileURL = home.appendingPathComponent("GameSave0_GD.sav")
        let original = SaveCodec.encode(Self.fixtureJSON)
        try original.write(to: fileURL)

        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled(), home: home)
        model.load(url: fileURL)

        let badBackup = home.appendingPathComponent("bad.sav")
        try Data("not a real save".utf8).write(to: badBackup)   // readable but unparseable

        model.restore(from: badBackup)
        #expect(model.alert?.title == "Restore Failed")
        #expect(try Data(contentsOf: fileURL) == original)      // live file NOT overwritten
    }

    @Test func restoreReplacesLiveFileReloadsAndSnapshotsInMemoryState() throws {
        let home = try tempHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let fileURL = home.appendingPathComponent("GameSave0_GD.sav")
        try SaveCodec.encode(Self.fixtureJSON).write(to: fileURL)

        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled(), home: home)
        model.load(url: fileURL)

        let backupJSON = #"{"PlayerInfo":{"m_Gold":777,"m_Bei":5,"m_ChefFlame":1,"m_researchPoint":42,"m_trustPoint":100,"m_FakePoint":100},"SNSInfo":{"m_Follow_Count":7},"Ingredients":{},"InventoryItemSlot":{},"MermanVillInventory":{}}"#
        let backupData = SaveCodec.encode(backupJSON)
        let backupURL = home.appendingPathComponent("GameSave0_GD_snapshot.sav")
        try backupData.write(to: backupURL)

        model.applyText(.gold, "424242")               // unsaved in-memory edit
        model.restore(from: backupURL)

        #expect(model.alert?.title == "Backup Restored")
        #expect(model.value(.gold) == 777)             // reloaded from the backup
        #expect(model.hasChanges == false)             // fresh clean baseline
        #expect(try Data(contentsOf: fileURL) == backupData)   // live file replaced

        // The safety backup captured the pre-restore IN-MEMORY state (gold 424242) → reversible.
        let safeties = BackupStore.listBackups(for: fileURL, bundleID: SaveEditorModel.bundleID, home: home)
        #expect(safeties.count == 1)
        let snapshot = try SaveDocument.load(Data(contentsOf: safeties[0]))
        #expect(snapshot.gold == 424242)
    }
}
