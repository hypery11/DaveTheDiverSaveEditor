import Foundation
import Testing
@testable import DaveSaveCore

struct BackupStoreTests {
    private let bundleID = "com.example.davesave"

    private func uniqueHome() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    /// Mirror the production formatter exactly so the expected filename is timezone-stable.
    private func expectedTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: date)
    }

    @discardableResult
    private func writeFile(_ url: URL, _ bytes: Data, modified: Date? = nil) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url)
        if let modified { try fm.setAttributes([.modificationDate: modified], ofItemAtPath: url.path) }
        return url
    }

    @Test func backupDirectoryIsUnderAppSupportBundleBackups() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let dir = BackupStore.backupDirectory(bundleID: bundleID, home: home)
        #expect(dir.path == "/Users/tester/Library/Application Support/\(bundleID)/Backups")
    }

    @Test func backupWritesTimestampedFilenameInPerSaveSubfolderAndCopiesBytes() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let original = home.appendingPathComponent("save/GameSave0_GD.sav")
        let payload = Data("hello-cjk-白毛鸡".utf8)
        try writeFile(original, payload)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let backupURL = try BackupStore.backup(original: original, bundleID: bundleID, now: now, home: home)

        #expect(backupURL.lastPathComponent == "GameSave0_GD_\(expectedTimestamp(now)).sav")
        #expect(backupURL.deletingLastPathComponent().path
                == BackupStore.backupSubdirectory(for: original, bundleID: bundleID, home: home).path)
        #expect(try Data(contentsOf: backupURL) == payload)
    }

    @Test func listBackupsForSaveReturnsNewestFirstScopedByStemAndSubfolder() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let saveURL = home.appendingPathComponent("save/GameSave0_GD.sav")
        let sub = BackupStore.backupSubdirectory(for: saveURL, bundleID: bundleID, home: home)

        let older = try writeFile(sub.appendingPathComponent("GameSave0_GD_20250101_000000.sav"),
                                  Data([0x00]), modified: Date(timeIntervalSince1970: 1_000))
        let newer = try writeFile(sub.appendingPathComponent("GameSave0_GD_20260101_000000.sav"),
                                  Data([0x00]), modified: Date(timeIntervalSince1970: 9_000))
        try writeFile(sub.appendingPathComponent("README.txt"),                  // ignored (not .sav)
                      Data([0x00]), modified: Date(timeIntervalSince1970: 5_000))
        try writeFile(sub.appendingPathComponent("OtherSave_GD_20260101_000000.sav"),  // wrong stem, filtered out
                      Data([0x00]), modified: Date(timeIntervalSince1970: 9_999))

        let list = BackupStore.listBackups(for: saveURL, bundleID: bundleID, home: home)
        #expect(list.map { $0.lastPathComponent } == [newer.lastPathComponent, older.lastPathComponent])
    }

    /// The multi-account fix: two saves with the SAME basename in different folders get
    /// separate subfolders, so they never share or overwrite each other's backups.
    @Test func sameNamedSavesInDifferentFoldersAreIsolated() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let saveA = home.appendingPathComponent("acctA/76561198000000000/GameSave0_GD.sav")
        let saveB = home.appendingPathComponent("acctB/76561198111111111/GameSave0_GD.sav")
        try writeFile(saveA, Data("A".utf8))
        try writeFile(saveB, Data("B".utf8))

        let bA = try BackupStore.backup(original: saveA, bundleID: bundleID, now: now, home: home)
        let bB = try BackupStore.backup(original: saveB, bundleID: bundleID, now: now, home: home)
        #expect(bA.lastPathComponent == bB.lastPathComponent)   // identical name…
        #expect(bA.path != bB.path)                             // …but different subfolders

        let listA = BackupStore.listBackups(for: saveA, bundleID: bundleID, home: home)
        let listB = BackupStore.listBackups(for: saveB, bundleID: bundleID, home: home)
        #expect(listA.map(\.path) == [bA.path])
        #expect(listB.map(\.path) == [bB.path])
        #expect(try Data(contentsOf: listA[0]) == Data("A".utf8))
        #expect(try Data(contentsOf: listB[0]) == Data("B".utf8))
    }

    @Test func backupDataWritesInMemoryBytesToTheSaveSubfolder() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let saveURL = home.appendingPathComponent("save/GameSave0_GD.sav")   // need not exist on disk
        let bytes = Data("in-memory-edits".utf8)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let url = try BackupStore.backupData(bytes, forSaveNamed: saveURL, bundleID: bundleID, now: now, home: home)
        #expect(url.lastPathComponent == "GameSave0_GD_\(expectedTimestamp(now)).sav")
        #expect(url.deletingLastPathComponent().path
                == BackupStore.backupSubdirectory(for: saveURL, bundleID: bundleID, home: home).path)
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func writeAtomicallyWritesThenOverwrites() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let target = home.appendingPathComponent("out.sav")

        try BackupStore.writeAtomically(Data("first".utf8), to: target)
        #expect(try Data(contentsOf: target) == Data("first".utf8))

        try BackupStore.writeAtomically(Data("second".utf8), to: target)
        #expect(try Data(contentsOf: target) == Data("second".utf8))
    }
}
