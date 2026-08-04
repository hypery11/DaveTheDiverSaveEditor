import Foundation
import Testing
import DaveSaveCore
@testable import DaveTheDiverSaveEditor

/// Covers the support prompt's triggers. The write total lives in `UserDefaults.standard`, so
/// each test saves and restores it.
@MainActor
@Suite("Support prompt", .serialized)
struct SupportAskTests {

    private func withCleanCount(_ body: () throws -> Void) rethrows {
        let d = UserDefaults.standard
        let saved = d.object(forKey: SupportAsk.writeCountKey)
        d.removeObject(forKey: SupportAsk.writeCountKey)
        defer {
            if let saved { d.set(saved, forKey: SupportAsk.writeCountKey) }
            else { d.removeObject(forKey: SupportAsk.writeCountKey) }
        }
        try body()
    }

    private static let fixture = #"{"PlayerInfo":{"m_Gold":100},"SNSInfo":{"m_Follow_Count":1}}"#

    @Test("the launch prompt is due in every language")
    func launchPromptAlwaysDue() throws {
        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled())
        model.offerSupportAtLaunch()
        #expect(model.supportPrompt?.id == "launch")
    }

    /// Every third write, and only every third.
    @Test("fires on the 3rd, 6th and 9th write and not in between")
    func firesEveryThirdWrite() {
        withCleanCount {
            var fired: [Int] = []
            for i in 1...9 {
                if let total = SupportAsk.registerWriteAndCheck() { fired.append(total) }
                _ = i
            }
            #expect(fired == [3, 6, 9])
        }
    }

    @Test("the write total persists across model instances")
    func countPersists() throws {
        try withCleanCount {
            _ = SupportAsk.registerWriteAndCheck()
            _ = SupportAsk.registerWriteAndCheck()
            #expect(UserDefaults.standard.integer(forKey: SupportAsk.writeCountKey) == 2)
            // A fresh model must not restart the count, or the prompt would never recur.
            let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled())
            model.registerWriteForSupportPrompt()
            #expect(model.supportPrompt?.id == "writes-3")
        }
    }

    @Test("a successful write is tagged writeSucceeded, which is what drives the counter")
    func successfulWriteIsTagged() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("dtdask-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let url = home.appendingPathComponent("GameSave_0_GD.sav", isDirectory: false)
        try SaveCodec.encode(Self.fixture).write(to: url)

        let model = SaveEditorModel(referenceDB: try ReferenceDB.bundled(), home: home)
        model.load(url: url)
        model.applyText(.gold, "500")
        #expect(model.write() != nil)
        #expect(model.alert?.kind == .writeSucceeded)
    }

    /// The one thing stored is a bare write total — no timestamps, no per-save detail, and
    /// nothing about *what* was edited. Pinned so that stays true.
    @Test("stores only a bare write total")
    func storesOnlyACount() {
        withCleanCount {
            _ = SupportAsk.registerWriteAndCheck()
            let ours = UserDefaults.standard.dictionaryRepresentation().keys
                .filter { $0.hasPrefix("SupportAsk") }
            #expect(Set(ours) == Set([SupportAsk.writeCountKey]))
            #expect(UserDefaults.standard.object(forKey: SupportAsk.writeCountKey) is Int)
        }
    }
}
