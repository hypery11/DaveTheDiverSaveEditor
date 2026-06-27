import Foundation
import Testing
@testable import DaveSaveCore

@Suite struct IngredientOpsTests {
    private func freshDB() throws -> (ReferenceDB, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ref-\(UUID().uuidString).sqlite")
        try makeTinyReferenceDB(at: url)
        return (try ReferenceDB(url: url), url)
    }

    private func loadDoc(_ json: String) throws -> SaveDocument {
        try SaveDocument.load(SaveCodec.encode(json))
    }

    @Test func maxOwnedSetsTieredCountOnExistingEntries() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let json = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":5}}}"#
        var doc = try loadDoc(json)
        doc.maxOwnedIngredients(using: db)
        let out = SaveCodec.decode(doc.encoded())
        let expected = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":6666}}}"#
        #expect(out == expected)
    }

    @Test func maxOwnedDoesNotInjectMissingEntries() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        // Only 1020201 is owned; Max-Own must never add 1021011 etc.
        let json = #"{"Ingredients":{"1020201":{"ingredientsID":1020201,"count":5}}}"#
        var doc = try loadDoc(json)
        doc.maxOwnedIngredients(using: db)
        let out = SaveCodec.decode(doc.encoded())
        #expect(out == #"{"Ingredients":{"1020201":{"ingredientsID":1020201,"count":6666}}}"#)
    }

    @Test func maxAllInjectsMissingEntryWithNineKeyShape() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        // installedDLCs = [14252001] -> DLCType 1 kept, DLCType 5 (needs 14252401) filtered out.
        // 1020201 exists -> count updated; 1021011 (tier 66) injected; 1025901 (tier 0) skipped.
        let json = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":5}}}"#
        var doc = try loadDoc(json)
        doc.maxAllIngredients(using: db)
        let out = SaveCodec.decode(doc.encoded())
        let expected = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":6666},"1021011":{"ingredientsID":1021011,"parentID":1011701,"count":66,"level":1,"branchCount":0,"isNew":true,"placeTagMask":1,"lastGainTime":"04/01/2025 12:34:56","lastGainGameTime":"10/03/2022 08:30:52"}}}"#
        #expect(out == expected)
    }

    @Test func maxAllExcludesUninstalledDLCAndSkipsLowTier() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let json = #"{"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{}}"#
        var doc = try loadDoc(json)
        doc.maxAllIngredients(using: db)
        let out = SaveCodec.decode(doc.encoded())
        #expect(out.contains("1021011"))     // DLCType 0, tier 66 -> injected
        #expect(!out.contains("1027019"))    // DLCType 5 not installed -> excluded
        #expect(!out.contains("1025901"))    // MaxCount 1 -> tier 0 -> skipped
    }

    @Test func maxAllIncludesInstalledDLC() throws {
        let (db, url) = try freshDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let json = #"{"GameInfo":{"installedDLCs":[14252001,14252401]},"Ingredients":{}}"#
        var doc = try loadDoc(json)
        doc.maxAllIngredients(using: db)
        let out = SaveCodec.decode(doc.encoded())
        #expect(out.contains("1027019"))     // DLCType 5 installed (14252401) -> injected
    }

    @Test func realSaveMaxAllIngredientsStaysValidAndPreservesCJK() throws {
        let url = URL(fileURLWithPath:
            "/Volumes/OWC Envoy Ultra/dave-the-diver-save-editor/LocalFixtures/real_sample_GD.sav")
        guard let raw = try? Data(contentsOf: url) else { return }   // skip-if-absent
        var doc = try SaveDocument.load(raw)
        let ref = try ReferenceDB.bundled()
        doc.maxAllIngredients(using: ref)                 // length-changing inject
        let out = doc.encoded()
        let reloaded = try SaveDocument.load(out)          // must still be valid JSON after length change
        #expect(reloaded.gold == doc.gold)                 // unrelated fields intact
        // CJK / FarmAnimal content must survive the length-changing edit (the upstream bug we fix):
        let decoded = SaveCodec.decode(out)
        #expect(decoded.contains("FarmAnimal"))
        #expect(!decoded.contains("\u{FFFD}"))             // ZERO replacement chars
    }
}
