import Testing
import Foundation
@testable import DaveSaveCore

@Suite struct AberrationExclusionTests {
    // 1020201 is a DLCType-1 DREDGE aberration (perishable); 1021006 is a normal ingredient.
    private func makeSave() throws -> SaveDocument {
        let json = #"{"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":0},"1021006":{"ingredientsID":1021006,"count":3}}}"#
        return try SaveDocument.load(SaveCodec.encode(json))
    }

    @Test func maxOwnedSkipsAberrationFishButMaxesNormal() throws {
        var d = try makeSave()
        d.maxOwnedIngredients(using: try ReferenceDB.bundled())
        let out = SaveCodec.decode(d.encoded())
        #expect(out.contains(#""ingredientsID":1020201,"count":0"#))   // aberration untouched
        #expect(out.contains(#""ingredientsID":1021006,"count":6666"#)) // normal maxed
    }

    @Test func maxAllSkipsAberrationFish() throws {
        var d = try makeSave()
        d.maxAllIngredients(using: try ReferenceDB.bundled())
        // The aberration must remain at 0 (never raised, never re-injected at a tier value).
        #expect(SaveCodec.decode(d.encoded()).contains(#""ingredientsID":1020201,"count":0"#))
    }
}
