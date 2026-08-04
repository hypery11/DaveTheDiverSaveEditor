import Foundation
import Testing
@testable import DaveSaveCore

@Suite struct FarmOpsTests {
    private func loadDoc(_ json: String) throws -> SaveDocument {
        try SaveDocument.load(SaveCodec.encode(json))
    }

    @Test func maxFarmStorageRaisesOwnedAndSkipsEmptySlots() throws {
        // One owned seed (soybean, ID 11070003, Count 89), one near-max, one empty (ID 0).
        let json = #"{"Farm":{"Storage":[{"ID":11070003,"Count":89,"Value":0,"Name":null,"IsNew":false},{"ID":11070105,"Count":9986,"Value":0,"Name":null,"IsNew":false},{"ID":0,"Count":0,"Value":0,"Name":null,"IsNew":false}]}}"#
        var doc = try loadDoc(json)
        let n = doc.maxFarmStorage()
        #expect(n == 2)                                       // both owned raised; empty skipped
        let out = SaveCodec.decode(doc.encoded())
        #expect(out.contains(#""ID":11070003,"Count":9999"#))  // soybean filled
        #expect(out.contains(#""ID":11070105,"Count":9999"#))  // near-max filled
        #expect(out.contains(#""ID":0,"Count":0"#))            // empty slot untouched
    }

    @Test func maxFarmStorageNoStorageIsNoop() throws {
        var doc = try loadDoc(#"{"Farm":{}}"#)
        #expect(doc.maxFarmStorage() == 0)
    }
}
