import Foundation
import Testing
@testable import DaveSaveCore

@Suite("SaveDocument")
struct SaveDocumentTests {

    /// Compact, synthetic save JSON (never a real user's save).
    static let fixtureJSON =
        #"{"PlayerInfo":{"m_Gold":12345,"m_Bei":678,"m_ChefFlame":90},"SNSInfo":{"m_Follow_Count":42}}"#

    /// Build `.sav` bytes for the fixture using the Task-2 codec.
    static func fixtureData() -> Data {
        SaveCodec.encode(fixtureJSON)
    }

    @Test("load decodes + parses; currency getters read the lexemes")
    func loadReadsCurrencies() throws {
        let doc = try SaveDocument.load(Self.fixtureData())
        #expect(doc.gold == 12345)
        #expect(doc.bei == 678)
        #expect(doc.artisansFlame == 90)
        #expect(doc.followerCount == 42)
    }

    @Test("missing currency path reads as 0")
    func missingFieldIsZero() throws {
        let doc = try SaveDocument.load(SaveCodec.encode(#"{"PlayerInfo":{}}"#))
        #expect(doc.gold == 0)
        #expect(doc.followerCount == 0)
    }

    @Test("invalid JSON throws JSONParseError")
    func invalidJSONThrows() {
        let data = SaveCodec.encode("{not json")
        #expect(throws: JSONParseError.self) {
            _ = try SaveDocument.load(data)
        }
    }

    @Test("setGold to max sets value and survives an encode round-trip")
    func setGoldRoundTrips() throws {
        var doc = try SaveDocument.load(Self.fixtureData())
        doc.setGold(999_999_999)
        #expect(doc.gold == 999_999_999)

        let reloaded = try SaveDocument.load(doc.encoded())
        #expect(reloaded.gold == 999_999_999)
        // Untouched fields are preserved through the round-trip.
        #expect(reloaded.bei == 678)
        #expect(reloaded.artisansFlame == 90)
        #expect(reloaded.followerCount == 42)
    }

    @Test("setGold clamps above the currency cap")
    func setGoldClamps() throws {
        var doc = try SaveDocument.load(Self.fixtureData())
        doc.setGold(10_000_000_000)
        #expect(doc.gold == 999_999_999)
    }

    @Test("setBei and setArtisansFlame clamp to the cap")
    func beiAndFlameClamp() throws {
        var doc = try SaveDocument.load(Self.fixtureData())
        doc.setBei(10_000_000_000)
        doc.setArtisansFlame(10_000_000_000)
        #expect(doc.bei == 999_999_999)
        #expect(doc.artisansFlame == 999_999_999)
    }

    @Test("setFollowerCount is NOT clamped")
    func followerNotClamped() throws {
        var doc = try SaveDocument.load(Self.fixtureData())
        doc.setFollowerCount(10_000_000_000)
        #expect(doc.followerCount == 10_000_000_000)
        let reloaded = try SaveDocument.load(doc.encoded())
        #expect(reloaded.followerCount == 10_000_000_000)
    }

    @Test("pendingChanges reports gold old -> new and nothing else")
    func pendingChangesReportsGold() throws {
        var doc = try SaveDocument.load(Self.fixtureData())
        #expect(doc.pendingChanges().isEmpty)

        doc.setGold(999_999_999)
        let changes = doc.pendingChanges()
        #expect(changes == [FieldChange(path: "PlayerInfo.m_Gold",
                                        oldValue: "12345",
                                        newValue: "999999999")])
    }

    @Test("real save: load/encode round-trips byte-identical, edits persist")
    func realSaveLoadEncodeRoundTripsAndEdits() throws {
        let url = URL(fileURLWithPath:
            "/Volumes/OWC Envoy Ultra/dave-the-diver-save-editor/LocalFixtures/real_sample_GD.sav")
        guard let raw = try? Data(contentsOf: url) else { return }   // skip-if-absent
        var doc = try SaveDocument.load(raw)
        #expect(doc.encoded() == raw)            // load -> encode with NO edits is byte-identical
        #expect(doc.gold >= 0)                    // currency reads succeed
        let before = doc.gold
        doc.setGold(999_999_999)
        #expect(doc.gold == 999_999_999)
        let changes = doc.pendingChanges()
        #expect(changes.contains { $0.path.contains("m_Gold") && $0.oldValue == String(before) })
        // re-load the edited bytes and confirm the edit persisted, nothing else corrupted
        let reloaded = try SaveDocument.load(doc.encoded())
        #expect(reloaded.gold == 999_999_999)
    }
}
