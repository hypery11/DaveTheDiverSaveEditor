import Foundation

/// Detects whether Steam Cloud is holding a copy of the save we are about to edit.
///
/// This is the single most common reason a player believes a save editor is broken: Steam
/// notices the local file differs from the cloud version and restores the *old* cloud copy
/// before the game loads, so the edit appears to have silently done nothing. Every tool in
/// this space documents the workaround after the fact; none of them detects it.
///
/// **Warning, never blocking.** Plenty of players legitimately have Cloud off, or want to
/// write anyway and pull the file across themselves. This reports; the caller decides.
///
/// Entirely local file I/O — no network, and it never reads Steam's credentials. Note what
/// is deliberately NOT attempted: `localconfig.vdf` does contain a per-app entry, but for
/// this app id the value is an opaque hex blob rather than a readable cloud on/off flag
/// (verified against a real install), so the presence and freshness of the staged copy is
/// the honest signal available.
public enum SteamCloudGuard {

    /// Dave the Diver's Steam application id. Its cloud staging lives under
    /// `Steam/userdata/<steam-id>/<appid>/remote/`.
    private static let appID = "1868140"

    public struct Status: Equatable, Sendable {
        /// Steam has a staged cloud copy of this exact save file.
        public let cloudCopyExists: Bool
        /// That staged copy is newer than the save on disk — Steam is very likely to win.
        public let cloudCopyIsNewer: Bool
        /// When the staged copy was last written, if there is one.
        public let cloudCopyModified: Date?

        public init(cloudCopyExists: Bool, cloudCopyIsNewer: Bool, cloudCopyModified: Date?) {
            self.cloudCopyExists = cloudCopyExists
            self.cloudCopyIsNewer = cloudCopyIsNewer
            self.cloudCopyModified = cloudCopyModified
        }

        /// Nothing staged for this file — either Cloud is off for the game, or it has never
        /// synced this slot.
        public static let notSyncing = Status(cloudCopyExists: false,
                                             cloudCopyIsNewer: false,
                                             cloudCopyModified: nil)
    }

    /// Look for a staged cloud copy of `saveURL`, matching on file name.
    ///
    /// `home` overrides the home directory so tests never touch a real Steam install.
    public static func check(saveURL: URL,
                             fileManager: FileManager = .default,
                             home: URL? = nil) -> Status {
        let root = (home ?? fileManager.homeDirectoryForCurrentUser)
            .appendingPathComponent("Library/Application Support/Steam/userdata", isDirectory: true)
        guard let accounts = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return .notSyncing
        }

        let name = saveURL.lastPathComponent
        let localModified = modified(of: saveURL, fileManager)

        // One directory per signed-in Steam account. Any of them staging this file means
        // Cloud is live for the game, so the first hit is enough.
        for account in accounts {
            let staged = account
                .appendingPathComponent(appID, isDirectory: true)
                .appendingPathComponent("remote", isDirectory: true)
                .appendingPathComponent(name, isDirectory: false)
            guard fileManager.fileExists(atPath: staged.path) else { continue }
            let cloudModified = modified(of: staged, fileManager)
            let isNewer: Bool
            if let cloudModified, let localModified {
                isNewer = cloudModified > localModified
            } else {
                isNewer = false
            }
            return Status(cloudCopyExists: true,
                          cloudCopyIsNewer: isNewer,
                          cloudCopyModified: cloudModified)
        }
        return .notSyncing
    }

    private static func modified(of url: URL, _ fileManager: FileManager) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
