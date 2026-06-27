import Foundation

public enum BackupStore {

    /// `~/Library/Application Support/<bundleID>/Backups/`
    public static func backupDirectory(bundleID: String, home: URL? = nil) -> URL {
        let resolvedHome = home ?? FileManager.default.homeDirectoryForCurrentUser
        return resolvedHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    /// Copy `original` into the backup directory as `<stem>_yyyyMMdd_HHmmss.sav`
    /// (en_US_POSIX, local time). Overwrites a same-second collision. Returns the backup URL.
    @discardableResult
    public static func backup(original: URL, bundleID: String, now: Date = Date(), home: URL? = nil) throws -> URL {
        let fileManager = FileManager.default
        let dir = backupDirectory(bundleID: bundleID, home: home)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let stem = original.deletingPathExtension().lastPathComponent
        let timestamp = timestampFormatter().string(from: now)
        let destination = dir.appendingPathComponent("\(stem)_\(timestamp).sav", isDirectory: false)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: original, to: destination)
        return destination
    }

    /// All `.sav` backups in the backup directory, newest `contentModificationDate` first.
    public static func listBackups(bundleID: String, home: URL? = nil) -> [URL] {
        let fileManager = FileManager.default
        let dir = backupDirectory(bundleID: bundleID, home: home)
        guard let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return [] }

        let saves = names.compactMap { name -> URL? in
            guard name.hasSuffix(".sav") else { return nil }
            let url = dir.appendingPathComponent(name, isDirectory: false)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
                return nil
            }
            return url
        }
        return saves.sorted { lhs, rhs in
            let lDate = modificationDate(of: lhs)
            let rDate = modificationDate(of: rhs)
            if lDate != rDate { return lDate > rDate }
            return lhs.lastPathComponent > rhs.lastPathComponent
        }
    }

    /// Atomic write via `Data.write(options: .atomic)`.
    public static func writeAtomically(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Helpers

    private static func timestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }

    private static func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }
}
