import Foundation
import Testing
@testable import DaveSaveCore

@Suite struct ReferenceDBTests {
    private func freshDB() throws -> (ReferenceDB, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ref-\(UUID().uuidString).sqlite")
        try makeTinyReferenceDB(at: url)
        return (try ReferenceDB(url: url), url)
    }

    @Test func maxCountReturnsKnownRow() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(db.maxCount(itemDataID: 1020201) == 9999)
        #expect(db.maxCount(itemDataID: 1021011) == 99)
        #expect(db.maxCount(itemDataID: 1025901) == 1)
    }

    @Test func maxCountReturnsNilForMissingItem() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(db.maxCount(itemDataID: 99_999_999) == nil)
    }

    @Test func allIngredientsJoinsItemsByItemDataID() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let rows = db.allIngredients()
        #expect(rows.count == 4)
        // parentID is the matched Items.TID (primary key), not the ItemDataID.
        #expect(rows.contains(IngredientRow(id: 1020201, parentID: 1010201, maxCount: 9999, dlcType: 1)))
        #expect(rows.contains(IngredientRow(id: 1021011, parentID: 1011701, maxCount: 99,   dlcType: 0)))
        #expect(rows.contains(IngredientRow(id: 1025901, parentID: 1018901, maxCount: 1,    dlcType: 0)))
        #expect(rows.contains(IngredientRow(id: 1027019, parentID: 1017019, maxCount: 9999, dlcType: 5)))
    }

    @Test func initThrowsForMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).sqlite")
        #expect(throws: (any Error).self) { _ = try ReferenceDB(url: url) }
    }
}
