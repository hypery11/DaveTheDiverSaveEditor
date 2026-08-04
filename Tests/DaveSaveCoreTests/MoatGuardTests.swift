import Testing
import Foundation
import DaveSaveCore

// Permanent CI regression guard for the project's core differentiator:
//   - byte-identity on untouched load/encode cycle
//   - CJK content survives a length-changing ingredient inject (maxAllIngredients)
//   - zero U+FFFD replacement characters after the inject
//
// Uses a purely inline synthetic save — no committed binary, no local fixture,
// always runs in CI.

private let syntheticSave =
    #"{"PlayerInfo":{"m_Gold":100,"m_Bei":50,"m_ChefFlame":3},"SNSInfo":{"m_Follow_Count":200},"LastUpdateTime":639182153449994890,"GameInfo":{"installedDLCs":[]},"Ingredients":{"1021011":{"ingredientsID":1021011,"count":10}},"FarmAnimal":[{"FarmAnimalID":11090002,"Name":"白毛雞"}]}"#

@Suite struct MoatGuardTests {

    // Encode the inline JSON to .sav bytes once; reused by all tests below.
    private let raw: Data = SaveCodec.encode(syntheticSave)

    @Test func byteIdentityOnUnmodifiedLoad() throws {
        let doc = try SaveDocument.load(raw)
        #expect(doc.encoded() == raw)
    }

    @Test func cjkPreservedAndNoReplacementCharsAfterMaxAllIngredients() throws {
        var doc = try SaveDocument.load(raw)
        let ref = try ReferenceDB.bundled()
        doc.maxAllIngredients(using: ref)   // length-changing inject
        let out = doc.encoded()

        // Must still parse as valid JSON after a length-changing edit.
        _ = try SaveDocument.load(out)

        let decoded = SaveCodec.decode(out)
        // CJK FarmAnimal name survives byte-level rewrite.
        #expect(decoded.contains("白毛雞"))
        // Absolutely zero Unicode replacement characters.
        #expect(!decoded.contains("\u{FFFD}"))
    }
}
