import Foundation
import Testing
@testable import DaveSaveCore

struct SaveLocatorTests {

    private func uniqueHome() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SaveLocatorTests-\(UUID().uuidString)", isDirectory: true)
    }

    @discardableResult
    private func writeFile(_ url: URL, modified: Date) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xAB]).write(to: url)
        try fm.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    @Test func candidateRootsAreTheThreeKnownNexonRoots() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let roots = SaveLocator.candidateRoots(home: home)
        #expect(roots.count == 3)
        let suffixes = roots.map { $0.path.replacingOccurrences(of: home.path, with: "") }
        #expect(suffixes[0] == "/Library/Application Support/nexon/DAVE THE DIVER/SteamSData")
        #expect(suffixes[1] == "/Library/Application Support/nexon/DAVE THE DIVER/SData")
        #expect(suffixes[2] == "/Library/Application Support/com.nexon.dave/SteamSData")
    }

    @Test func newestSaveReturnsNilWhenNoSavesExist() {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        #expect(SaveLocator.newestSave(home: home) == nil)
    }

    @Test func newestSavePicksNewestAcrossRootAndNumericSubfolder() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let steam = SaveLocator.candidateRoots(home: home)[0]   // .../SteamSData

        // older manual save directly in the root
        try writeFile(steam.appendingPathComponent("m_old.sav"),
                      modified: Date(timeIntervalSince1970: 1_000))
        // numeric steam-id subfolder holding the newest autosave
        let idFolder = steam.appendingPathComponent("76561198000000000", isDirectory: true)
        let newest = try writeFile(idFolder.appendingPathComponent("GameSave0_GD.sav"),
                                   modified: Date(timeIntervalSince1970: 5_000))
        // decoy in a NON-numeric subfolder, even newer -> must be ignored
        try writeFile(steam.appendingPathComponent("backup_copies", isDirectory: true)
                        .appendingPathComponent("GameSave9_GD.sav"),
                      modified: Date(timeIntervalSince1970: 9_000))
        // decoy with a non-matching filename in the id folder, even newer -> must be ignored
        try writeFile(idFolder.appendingPathComponent("notes.sav"),
                      modified: Date(timeIntervalSince1970: 8_000))

        let candidate = SaveLocator.newestSave(home: home)
        #expect(candidate?.fileURL.lastPathComponent == "GameSave0_GD.sav")
        #expect(candidate?.directoryURL.lastPathComponent == "76561198000000000")
        #expect(candidate?.modified == Date(timeIntervalSince1970: 5_000))
        #expect(candidate?.fileURL.path == newest.path)
    }

    @Test func allSavesReturnsEveryMatchNewestFirst() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let steam = SaveLocator.candidateRoots(home: home)[0]
        try writeFile(steam.appendingPathComponent("m_old.sav"), modified: Date(timeIntervalSince1970: 1_000))
        let idFolder = steam.appendingPathComponent("76561198000000000", isDirectory: true)
        try writeFile(idFolder.appendingPathComponent("GameSave0_GD.sav"), modified: Date(timeIntervalSince1970: 5_000))
        try writeFile(idFolder.appendingPathComponent("GameSave1_GD.sav"), modified: Date(timeIntervalSince1970: 3_000))
        try writeFile(idFolder.appendingPathComponent("notes.sav"), modified: Date(timeIntervalSince1970: 9_000)) // non-match, ignored

        let all = SaveLocator.allSaves(home: home)
        #expect(all.map { $0.fileURL.lastPathComponent } == ["GameSave0_GD.sav", "GameSave1_GD.sav", "m_old.sav"])
        #expect(SaveLocator.newestSave(home: home)?.fileURL.lastPathComponent == "GameSave0_GD.sav") // still the first
    }

    @Test func newestSaveMatchesManualSaveInFallbackRoot() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let fallback = SaveLocator.candidateRoots(home: home)[2]   // com.nexon.dave/SteamSData (verified primary)
        let f = try writeFile(fallback.appendingPathComponent("m_slot1.sav"),
                              modified: Date(timeIntervalSince1970: 2_000))
        let candidate = SaveLocator.newestSave(home: home)
        #expect(candidate?.fileURL.path == f.path)
        #expect(candidate?.directoryURL.lastPathComponent == "SteamSData")
    }

    @Test func newestSaveFindsRealInstallIfPresent() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let realRoot = home.appendingPathComponent(
            "Library/Application Support/com.nexon.dave/SteamSData", isDirectory: true)
        guard FileManager.default.fileExists(atPath: realRoot.path) else { return } // skip-if-absent
        let candidate = SaveLocator.newestSave(home: home)
        #expect(candidate != nil)
        #expect(candidate?.fileURL.lastPathComponent.hasSuffix("_GD.sav") == true)
    }
}
