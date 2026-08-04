import Foundation

/// Module marker + version for the pure-Swift DaveSaveCore package.
///
/// The concrete types (`SaveCodec`, `OrderedJSON`, `ReferenceDB`,
/// `SaveDocument`, `SaveLocator`, `BackupStore`) are added by later tasks.
public enum DaveSaveCore {
    /// Semantic version of the core library.
    public static let version = "0.1.0"
}

/// Locates the bundled, read-only reference database resource.
///
/// `ReferenceDB.bundled()` (later task) reuses this to obtain the URL it
/// opens with `sqlite3_open_v2(..., SQLITE_OPEN_READONLY, ...)`.
internal enum ReferenceResource {
    /// URL of `reference.sqlite` inside `Bundle.module`, or `nil` if absent.
    static var url: URL? {
        Bundle.module.url(forResource: "reference", withExtension: "sqlite")
    }
}
