import Foundation
import Testing
@testable import DaveSaveCore

/// Every case builds a fake Steam tree under a temp `home`, so the tests never read the
/// machine's real Steam install (which would make them pass or fail by accident).
@Suite("SteamCloudGuard")
struct SteamCloudGuardTests {

    private struct Fixture {
        let home: URL
        let save: URL
        let stagedDir: URL
    }

    private func makeFixture(accountID: String = "100000000000001") throws -> Fixture {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("dtdcloud-\(UUID().uuidString)", isDirectory: true)
        let saveDir = home.appendingPathComponent("saves", isDirectory: true)
        let stagedDir = home
            .appendingPathComponent("Library/Application Support/Steam/userdata", isDirectory: true)
            .appendingPathComponent(accountID, isDirectory: true)
            .appendingPathComponent("1868140/remote", isDirectory: true)
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: stagedDir, withIntermediateDirectories: true)
        let save = saveDir.appendingPathComponent("GameSave_00_GD.sav", isDirectory: false)
        try Data("local".utf8).write(to: save)
        return Fixture(home: home, save: save, stagedDir: stagedDir)
    }

    @Test("no Steam directory at all reads as not syncing")
    func noSteamInstall() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("dtdcloud-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let save = home.appendingPathComponent("GameSave_00_GD.sav", isDirectory: false)
        try Data("x".utf8).write(to: save)

        #expect(SteamCloudGuard.check(saveURL: save, home: home) == .notSyncing)
    }

    @Test("a Steam install with nothing staged for this slot reads as not syncing")
    func nothingStaged() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.home) }
        #expect(SteamCloudGuard.check(saveURL: f.save, home: f.home) == .notSyncing)
    }

    @Test("a staged copy of the same file name is detected")
    func stagedCopyDetected() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.home) }
        try Data("cloud".utf8).write(to: f.stagedDir.appendingPathComponent("GameSave_00_GD.sav"))

        let status = SteamCloudGuard.check(saveURL: f.save, home: f.home)
        #expect(status.cloudCopyExists)
        #expect(status.cloudCopyModified != nil)
    }

    /// A different slot being staged must not warn about this one, or the warning becomes
    /// noise a user learns to dismiss.
    @Test("a staged copy of a DIFFERENT slot does not warn")
    func otherSlotIgnored() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.home) }
        try Data("cloud".utf8).write(to: f.stagedDir.appendingPathComponent("GameSave_02_GD.sav"))

        #expect(SteamCloudGuard.check(saveURL: f.save, home: f.home) == .notSyncing)
    }

    @Test("a staged copy newer than the local save is flagged as newer")
    func newerCloudCopyFlagged() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.home) }
        let staged = f.stagedDir.appendingPathComponent("GameSave_00_GD.sav")
        try Data("cloud".utf8).write(to: staged)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(3600)], ofItemAtPath: staged.path)

        let status = SteamCloudGuard.check(saveURL: f.save, home: f.home)
        #expect(status.cloudCopyExists)
        #expect(status.cloudCopyIsNewer)
    }

    @Test("an older staged copy is detected but not flagged as newer")
    func olderCloudCopyNotFlagged() throws {
        let f = try makeFixture()
        defer { try? FileManager.default.removeItem(at: f.home) }
        let staged = f.stagedDir.appendingPathComponent("GameSave_00_GD.sav")
        try Data("cloud".utf8).write(to: staged)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-3600)], ofItemAtPath: staged.path)

        let status = SteamCloudGuard.check(saveURL: f.save, home: f.home)
        #expect(status.cloudCopyExists)
        #expect(status.cloudCopyIsNewer == false)
    }

    /// Steam creates one directory per signed-in account; the save may be staged under any
    /// of them.
    @Test("finds the staged copy under a second Steam account")
    func multipleAccounts() throws {
        let f = try makeFixture(accountID: "111111111")
        defer { try? FileManager.default.removeItem(at: f.home) }
        let second = f.home
            .appendingPathComponent("Library/Application Support/Steam/userdata", isDirectory: true)
            .appendingPathComponent("222222222/1868140/remote", isDirectory: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try Data("cloud".utf8).write(to: second.appendingPathComponent("GameSave_00_GD.sav"))

        #expect(SteamCloudGuard.check(saveURL: f.save, home: f.home).cloudCopyExists)
    }
}
