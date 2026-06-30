import Foundation
import Testing
@testable import DaveSaveCore

@Suite struct CraftMaterialOpsTests {
    private func freshDB() throws -> (ReferenceDB, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ref-\(UUID().uuidString).sqlite")
        try makeTinyReferenceDB(at: url)
        return (try ReferenceDB(url: url), url)
    }

    private func loadDoc(_ json: String) throws -> SaveDocument {
        try SaveDocument.load(SaveCodec.encode(json))
    }

    // Tiny DB craft materials (ItemType 6): 1014980 (DLCType 1), 1018090 (DLCType 0).

    @Test func maxCraftRaisesOwnedAndInjectsMissingWhenDLCInstalled() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let json = #"{"GameInfo":{"installedDLCs":[14252001]},"InventoryItemSlot":{"g1":{"GUID":"g1","index":0,"itemID":1018090,"totalCount":5,"isNew":false}}}"#
        var doc = try loadDoc(json)
        let n = doc.maxCraftMaterials(using: db)
        #expect(n == 2)
        let out = SaveCodec.decode(doc.encoded())
        #expect(out.contains(#""itemID":1018090,"totalCount":999"#))  // owned base material raised
        #expect(out.contains(#""itemID":1014980,"totalCount":999"#))  // DREDGE part injected (DLC installed)
    }

    @Test func maxCraftGatesDLCMaterialsWhenDLCMissing() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let json = #"{"GameInfo":{"installedDLCs":[]},"InventoryItemSlot":{}}"#
        var doc = try loadDoc(json)
        let n = doc.maxCraftMaterials(using: db)
        #expect(n == 1)
        let out = SaveCodec.decode(doc.encoded())
        #expect(out.contains(#""itemID":1018090"#))     // base material injected
        #expect(!out.contains("1014980"))               // DLC-gated DREDGE part NOT injected
    }

    @Test func setInventoryItemUpdatesExistingAndInjectsMissing() throws {
        let json = #"{"InventoryItemSlot":{"g1":{"GUID":"g1","index":0,"itemID":1018090,"totalCount":5,"isNew":false}}}"#
        var doc = try loadDoc(json)
        let updated = doc.setInventoryItem(itemID: 1018090, count: 42)   // existing -> updated
        let injected = doc.setInventoryItem(itemID: 1014980, count: 7)   // missing  -> injected
        #expect(updated)
        #expect(injected)
        let out = SaveCodec.decode(doc.encoded())
        #expect(out.contains(#""itemID":1018090,"totalCount":42"#))
        #expect(out.contains(#""itemID":1014980,"totalCount":7"#))
    }

    @Test func setInventoryItemNoContainerIsNoop() throws {
        var doc = try loadDoc(#"{"PlayerInfo":{"m_Gold":1}}"#)
        let result = doc.setInventoryItem(itemID: 1014980, count: 7)
        #expect(result == false)
    }
}
