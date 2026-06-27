import Foundation

public struct SaveCandidate: Equatable {
    public let fileURL: URL
    public let directoryURL: URL
    public let modified: Date

    public init(fileURL: URL, directoryURL: URL, modified: Date) {
        self.fileURL = fileURL
        self.directoryURL = directoryURL
        self.modified = modified
    }
}

public enum SaveLocator {

    /// The three known nexon save roots, rooted under `home`.
    public static func candidateRoots(home: URL) -> [URL] {
        let appSupport = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        let nexon = appSupport
            .appendingPathComponent("nexon", isDirectory: true)
            .appendingPathComponent("DAVE THE DIVER", isDirectory: true)
        let comNexonDave = appSupport
            .appendingPathComponent("com.nexon.dave", isDirectory: true)
        return [
            nexon.appendingPathComponent("SteamSData", isDirectory: true),
            nexon.appendingPathComponent("SData", isDirectory: true),
            comNexonDave.appendingPathComponent("SteamSData", isDirectory: true), // verified real path
        ]
    }

    /// For each existing root, scan the root itself plus every immediate all-ASCII-digit
    /// subfolder; match `GameSave*_GD.sav` / `m_*.sav`; return the globally-newest file
    /// (by `contentModificationDate`) along with the directory it was found in.
    public static func newestSave(fileManager: FileManager = .default, home: URL? = nil) -> SaveCandidate? {
        let resolvedHome = home ?? fileManager.homeDirectoryForCurrentUser
        var best: SaveCandidate?

        for root in candidateRoots(home: resolvedHome) {
            guard isDirectory(root, fileManager: fileManager) else { continue }

            var scanDirs: [URL] = [root]
            for sub in immediateSubdirectories(of: root, fileManager: fileManager)
            where isAllASCIIDigits(sub.lastPathComponent) {
                scanDirs.append(sub)
            }

            for dir in scanDirs {
                for file in saveFiles(in: dir, fileManager: fileManager) {
                    guard let modified = modificationDate(of: file) else { continue }
                    if best == nil || modified > best!.modified {
                        best = SaveCandidate(fileURL: file, directoryURL: dir, modified: modified)
                    }
                }
            }
        }
        return best
    }

    // MARK: - Matching helpers

    static func isAllASCIIDigits(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        for scalar in name.unicodeScalars where scalar.value < 48 || scalar.value > 57 {
            return false
        }
        return true
    }

    static func isSaveFileName(_ name: String) -> Bool {
        let isAutosave = name.hasPrefix("GameSave") && name.hasSuffix("_GD.sav")
        let isManual = name.hasPrefix("m_") && name.hasSuffix(".sav")
        return isAutosave || isManual
    }

    // MARK: - FileManager helpers

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    private static func immediateSubdirectories(of url: URL, fileManager: FileManager) -> [URL] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: url.path) else { return [] }
        return names.compactMap { name -> URL? in
            let sub = url.appendingPathComponent(name, isDirectory: true)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: sub.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }
            return sub
        }
    }

    private static func saveFiles(in dir: URL, fileManager: FileManager) -> [URL] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: dir.path) else { return [] }
        return names.compactMap { name -> URL? in
            guard isSaveFileName(name) else { return nil }
            let file = dir.appendingPathComponent(name, isDirectory: false)
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: file.path, isDirectory: &isDir), !isDir.boolValue else {
                return nil
            }
            return file
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
