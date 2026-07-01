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

    /// Per-save subfolder `Backups/<folderToken>/`, namespaced by the save's containing
    /// directory. Dave the Diver reuses the SAME basenames (`GameSave0_GD.sav`, `m_*.sav`)
    /// across different Steam-id folders / roots, so without this two distinct saves would
    /// share a flat namespace and could offer / overwrite each other's backups.
    public static func backupSubdirectory(for saveURL: URL, bundleID: String, home: URL? = nil) -> URL {
        backupDirectory(bundleID: bundleID, home: home)
            .appendingPathComponent(folderToken(for: saveURL), isDirectory: true)
    }

    /// Copy `original` into its per-save subfolder as `<stem>_yyyyMMdd_HHmmss.sav`
    /// (en_US_POSIX, local time). Overwrites a same-second collision. Returns the backup URL.
    @discardableResult
    public static func backup(original: URL, bundleID: String, now: Date = Date(), home: URL? = nil) throws -> URL {
        try writeBackup(bytes: nil, copyingFrom: original, forSave: original, bundleID: bundleID, now: now, home: home)
    }

    /// Back up arbitrary in-memory bytes as a backup of `saveURL` — captures the live
    /// (possibly unsaved-edited) document, so a restore that reloads from disk is still
    /// fully reversible. Same naming/location as `backup(original:)`.
    @discardableResult
    public static func backupData(_ data: Data, forSaveNamed saveURL: URL, bundleID: String,
                                  now: Date = Date(), home: URL? = nil) throws -> URL {
        try writeBackup(bytes: data, copyingFrom: nil, forSave: saveURL, bundleID: bundleID, now: now, home: home)
    }

    /// Timestamped backups belonging to `saveURL` (its subfolder, filtered by `<stem>_`
    /// prefix), newest `contentModificationDate` first.
    public static func listBackups(for saveURL: URL, bundleID: String, home: URL? = nil) -> [URL] {
        let dir = backupSubdirectory(for: saveURL, bundleID: bundleID, home: home)
        let stem = saveURL.deletingPathExtension().lastPathComponent + "_"
        return savFiles(in: dir)
            .filter { $0.lastPathComponent.hasPrefix(stem) }
            .sorted(by: newestFirst)
    }

    /// Atomic write via `Data.write(options: .atomic)`.
    public static func writeAtomically(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Helpers

    private static func writeBackup(bytes: Data?, copyingFrom source: URL?, forSave saveURL: URL,
                                    bundleID: String, now: Date, home: URL?) throws -> URL {
        let fileManager = FileManager.default
        let dir = backupSubdirectory(for: saveURL, bundleID: bundleID, home: home)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let stem = saveURL.deletingPathExtension().lastPathComponent
        let timestamp = timestampFormatter().string(from: now)
        let destination = dir.appendingPathComponent("\(stem)_\(timestamp).sav", isDirectory: false)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        if let bytes {
            try bytes.write(to: destination)
        } else if let source {
            try fileManager.copyItem(at: source, to: destination)
        }
        return destination
    }

    /// Stable, filesystem-safe token for the save's containing folder (FNV-1a hash → hex).
    private static func folderToken(for saveURL: URL) -> String {
        let key = saveURL.deletingLastPathComponent().path
        var hash: UInt64 = 1469598103934665603              // FNV-1a offset basis
        for byte in key.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }

    private static func savFiles(in dir: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.compactMap { name -> URL? in
            guard name.hasSuffix(".sav") else { return nil }
            let url = dir.appendingPathComponent(name, isDirectory: false)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { return nil }
            return url
        }
    }

    private static func newestFirst(_ lhs: URL, _ rhs: URL) -> Bool {
        let l = modificationDate(of: lhs), r = modificationDate(of: rhs)
        if l != r { return l > r }
        return lhs.lastPathComponent > rhs.lastPathComponent
    }

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
