import Testing
import Foundation
@testable import DaveSaveCore

@Suite struct PlayerResourcesOpsTests {
    // Synthetic compact save: research point + 3 inventory slots (stackable / unique / special)
    // + 1 merman slot. itemIDs are deliberately NOT in the reference DB so the
    // "unknown but stackable (count>1) -> 999" branch is exercised deterministically.
    private func makeSave() throws -> SaveDocument {
        let json = #"{"PlayerInfo":{"m_Gold":100,"m_researchPoint":50},"InventoryItemSlot":{"a":{"itemID":99999991,"totalCount":5},"b":{"itemID":99999992,"totalCount":1},"c":{"itemID":99999993,"totalCount":-1}},"MermanVillInventory":{"x":{"mvInvenItemID":1,"count":3}}}"#
        return try SaveDocument.load(SaveCodec.encode(json))
    }

    @Test func setsAndReadsResearchPoint() throws {
        var d = try makeSave()
        #expect(d.researchPoint == 50)
        d.setResearchPoint(999_999)
        #expect(d.researchPoint == 999_999)
    }

    @Test func researchPointClampsToNineNines() throws {
        var d = try makeSave()
        d.setResearchPoint(10_000_000_000)
        #expect(d.researchPoint == 999_999_999)
        d.setResearchPoint(-5)
        #expect(d.researchPoint == 0)
    }

    @Test func maxInventoryRaisesStackablesAndSkipsUniqueAndSpecial() throws {
        var d = try makeSave()
        let ref = try ReferenceDB.bundled()
        let changed = d.maxInventoryItems(using: ref)
        // a: count 5 (stackable, unknown id) -> 999 ; b: count 1 (likely unique) skip ; c: -1 (special) skip
        #expect(changed == 1)
        let out = SaveCodec.decode(d.encoded())
        #expect(out.contains(#""totalCount":999"#))   // a raised
        #expect(out.contains(#""totalCount":1"#))      // b untouched
        #expect(out.contains(#""totalCount":-1"#))     // c untouched
    }

    @Test func maxMermanInventoryRaisesCount() throws {
        var d = try makeSave()
        let changed = d.maxMermanInventory()
        #expect(changed == 1)
        #expect(SaveCodec.decode(d.encoded()).contains(#""count":999"#))
    }

    @Test func maxStaffLevelsRaisesOnlyBelowCap() throws {
        var d = try SaveDocument.load(SaveCodec.encode(
            #"{"Staff":{"g1":{"level":1},"g2":{"level":20}}}"#))
        let changed = d.maxStaffLevels()          // default cap 20
        #expect(changed == 1)                      // only g1 was below
        let json = SaveCodec.decode(d.encoded())
        #expect(json.contains(#""g1":{"level":20}"#))
        #expect(json.contains(#""g2":{"level":20}"#))
    }

    @Test func maxCaughtFishGradesRaisesOnlyBelowTop() throws {
        var d = try SaveDocument.load(SaveCodec.encode(
            #"{"CaughtFish":{"2010005":{"fishID":2010005,"grade":2},"2010006":{"fishID":2010006,"grade":5}}}"#))
        let changed = d.maxCaughtFishGrades()      // default top grade 5
        #expect(changed == 1)                      // only the grade-2 fish moved
        let json = SaveCodec.decode(d.encoded())
        #expect(json.contains(#""fishID":2010005,"grade":5"#))
    }
}
