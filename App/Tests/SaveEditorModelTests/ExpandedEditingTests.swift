import Testing
import Foundation
import DaveSaveCore
@testable import DaveTheDiverSaveEditor

/// Covers the post-v1 editing surface wired into the model: research point (as a
/// fifth `Currency`), and the branch / inventory / merman bulk material ops. These
/// assert the model's UI wiring — status text and dirty/Write gating; the value-level
/// algorithms live in DaveSaveCore and are covered by its own tests.
@MainActor
@Suite struct ExpandedEditingTests {

    /// A save touching every expanded surface: research point, a branch-stocked
    /// ingredient, a stackable inventory slot, and a merman village slot.
    private static let fixtureJSON = #"""
    {"PlayerInfo":{"m_Gold":100,"m_Bei":5,"m_ChefFlame":1,"m_researchPoint":42},"SNSInfo":{"m_Follow_Count":7},"Ingredients":{"1021006":{"ingredientsID":1021006,"count":10,"branchCount":2}},"InventoryItemSlot":{"0":{"itemID":9999999,"totalCount":3}},"MermanVillInventory":{"0":{"count":5}}}
    """#

    private func loadedModel() throws -> SaveEditorModel {
        // Explicit bundled DB so the inventory/branch ops resolve deterministically.
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
        #expect(model.hasChanges)            // tracked via isDirty, not pendingChanges()
    }

    @Test func maximizeResearchPointClampsToButtonValue() throws {
        let model = try loadedModel()
        model.maximize(.researchPoint)
        #expect(model.value(.researchPoint) == 999_999_999)
    }

    // MARK: Material bulk ops — status + dirty wiring

    @Test func maxBranchSetsStatusAndDirties() throws {
        let model = try loadedModel()
        model.maxBranchIngredients()
        #expect(model.ingredientStatus == "Maxed branch (second store) ingredients.")
        #expect(model.hasChanges)
        #expect(model.alert == nil)
    }

    @Test func maxInventorySetsStatusAndDirties() throws {
        let model = try loadedModel()
        model.maxInventoryItems()
        #expect(model.ingredientStatus.hasPrefix("Maxed inventory items"))
        #expect(model.hasChanges)
        #expect(model.alert == nil)
    }

    @Test func maxMermanSetsStatusAndDirties() throws {
        let model = try loadedModel()
        model.maxMermanInventory()
        #expect(model.ingredientStatus.hasPrefix("Maxed merman village inventory"))
        #expect(model.hasChanges)
    }

    // MARK: The Write-gating fix

    /// A material-only edit changes no currency, so `pendingChanges()` stays empty —
    /// yet the Write button must enable. This is the regression `isDirty` fixes.
    @Test func materialOnlyEditEnablesWriteWithoutCurrencyChange() throws {
        let model = try loadedModel()
        #expect(model.hasChanges == false)
        model.maxMermanInventory()
        #expect(model.pendingChanges().isEmpty)   // no currency moved
        #expect(model.hasChanges)                  // …but Write is enabled
    }
}
