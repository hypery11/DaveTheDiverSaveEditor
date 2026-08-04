import Testing
import Foundation
@testable import DaveTheDiverSaveEditor
import DaveSaveCore

@MainActor
struct WriteFlowTests {

    /// Minimal valid save JSON carrying the four editable currency paths.
    private static let sampleJSON =
        #"{"PlayerInfo":{"m_Gold":100,"m_Bei":5,"m_ChefFlame":7},"SNSInfo":{"m_Follow_Count":3}}"#

    /// Encode a `.sav` fixture into a fresh temp home; return (home, fileURL).
    private func makeFixture() throws -> (home: URL, file: URL) {
        let home = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("dtdse-\(UUID().uuidString)", isDirectory: true)
        let dir = home.appendingPathComponent("saves", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("GameSave0_GD.sav")
        try SaveCodec.encode(Self.sampleJSON).write(to: file)
        return (home, file)
    }

    @Test
    func editThenWriteBacksUpAndPersistsValueAndAlertsSuccess() throws {
        let (home, file) = try makeFixture()
        defer { try? FileManager.default.removeItem(at: home) }

        let model = SaveEditorModel(referenceDB: nil, fileManager: .default, home: home)
        model.load(url: file)
        #expect(model.isLoaded)
        #expect(model.hasChanges == false)

        // Edit -> a pending change surfaces (drives the preview sheet).
        model.applyText(.gold, "12345")
        #expect(model.hasChanges)
        #expect(model.pendingChanges().contains { $0.path.contains("m_Gold") && $0.newValue == "12345" })

        // Write -> backup URL returned, success alert carries it for Reveal.
        let backup = model.write()
        #expect(backup != nil)
        #expect(model.alert != nil)
        #expect(model.alert?.revealURL == backup)
        if let backup {
            #expect(FileManager.default.fileExists(atPath: backup.path))
        }

        // The on-disk save now decodes to the edited value (round-trip safe).
        let reloaded = try SaveDocument.load(Data(contentsOf: file))
        #expect(reloaded.gold == 12345)
    }
}
