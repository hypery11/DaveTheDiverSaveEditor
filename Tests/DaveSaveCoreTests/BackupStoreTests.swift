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

    @Test func backupDirectoryIsUnderAppSupportBundleBackups() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let dir = BackupStore.backupDirectory(bundleID: bundleID, home: home)
        #expect(dir.path == "/Users/tester/Library/Application Support/\(bundleID)/Backups")
    }

    @Test func backupWritesTimestampedFilenameAndCopiesBytes() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let saveDir = home.appendingPathComponent("save", isDirectory: true)
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        let original = saveDir.appendingPathComponent("GameSave0_GD.sav")
        let payload = Data("hello-cjk-白毛鸡".utf8)
        try payload.write(to: original)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let backupURL = try BackupStore.backup(original: original, bundleID: bundleID, now: now, home: home)

        #expect(backupURL.lastPathComponent == "GameSave0_GD_\(expectedTimestamp(now)).sav")
        #expect(backupURL.deletingLastPathComponent().path
                == BackupStore.backupDirectory(bundleID: bundleID, home: home).path)
        #expect(try Data(contentsOf: backupURL) == payload)
    }

    @Test func listBackupsReturnsNewestFirstAndIgnoresNonSav() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let dir = BackupStore.backupDirectory(bundleID: bundleID, home: home)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fm = FileManager.default

        func make(_ name: String, _ modified: Date) throws -> URL {
            let u = dir.appendingPathComponent(name)
            try Data([0x00]).write(to: u)
            try fm.setAttributes([.modificationDate: modified], ofItemAtPath: u.path)
            return u
        }
        let older = try make("GameSave0_GD_20250101_000000.sav", Date(timeIntervalSince1970: 1_000))
        let newer = try make("GameSave0_GD_20260101_000000.sav", Date(timeIntervalSince1970: 9_000))
        _ = try make("README.txt", Date(timeIntervalSince1970: 5_000))   // must be ignored

        let list = BackupStore.listBackups(bundleID: bundleID, home: home)
        #expect(list.map { $0.lastPathComponent }
                == [newer.lastPathComponent, older.lastPathComponent])
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
