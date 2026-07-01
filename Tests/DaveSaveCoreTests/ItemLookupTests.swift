import Foundation
import Testing
@testable import DaveSaveCore

@Suite struct ItemLookupTests {
    private func freshDB() throws -> (ReferenceDB, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ref-\(UUID().uuidString).sqlite")
        try makeTinyReferenceDB(at: url)
        return (try ReferenceDB(url: url), url)
    }

    @Test func itemNameResolvesByTIDAndItemDataIDAndPrettifies() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(db.itemName(id: 1014980) == "Dredge ResearchPart")   // by TID, _Name stripped, _→space
        #expect(db.itemName(id: 1021006) == "Soybean")               // by ItemDataID
        #expect(db.itemName(id: 9_999_999) == nil)                   // unknown
    }

    @Test func searchItemsMatchesByNameSubstring() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let dredge = db.searchItems("Dredge")
        #expect(dredge.contains(ItemMatch(id: 1014980, name: "Dredge ResearchPart")))
        #expect(db.searchItems("zzzznope").isEmpty)
        #expect(db.searchItems("").isEmpty)
    }

    @Test func inventoryItemsEnumeratesSortedAndSkipsNegative() throws {
        let json = #"{"InventoryItemSlot":{"g1":{"itemID":1014980,"totalCount":5},"g2":{"itemID":1013101,"totalCount":-1},"g3":{"itemID":1011006,"totalCount":99}}}"#
        let doc = try SaveDocument.load(SaveCodec.encode(json))
        let items = doc.inventoryItems()
        #expect(items == [InventorySlot(itemID: 1011006, count: 99),
                          InventorySlot(itemID: 1014980, count: 5)])   // sorted, -1 skipped
    }
}
