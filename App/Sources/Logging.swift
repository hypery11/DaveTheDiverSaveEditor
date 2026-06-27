import Foundation
import OSLog

/// Internal facade over OSLog. Every line goes to the unified logging system
/// (subsystem == bundle id). When the process is launched with `-log`, each
/// line is *also* mirrored to a per-session file under
/// `~/Library/Logs/DaveTheDiverSaveEditor/`, so a user can attach a log to a
/// bug report without opening Console.
enum AppLog {
    /// OSLog subsystem; matches the app bundle identifier.
    static let subsystem = "app.davethediver.saveeditor"

    /// True when launched with `-log`. Evaluated once at process start.
    static let fileMirroringEnabled = CommandLine.arguments.contains("-log")

    static let app = Channel("app")     // lifecycle
    static let io = Channel("io")       // load / write / backup / detect
    static let model = Channel("model") // edits, ingredient ops

    struct Channel {
        let category: String
        private let logger: Logger

        init(_ category: String) {
            self.category = category
            self.logger = Logger(subsystem: AppLog.subsystem, category: category)
        }

        func info(_ message: String)   { logger.info("\(message, privacy: .public)");   mirror("INFO", message) }
        func notice(_ message: String) { logger.notice("\(message, privacy: .public)"); mirror("NOTICE", message) }
        func error(_ message: String)  { logger.error("\(message, privacy: .public)");  mirror("ERROR", message) }

        private func mirror(_ level: String, _ message: String) {
            guard AppLog.fileMirroringEnabled else { return }
            FileLogSink.shared.write("[\(level)] [\(category)] \(message)")
        }
    }
}

/// Serial, append-only file mirror used when `-log` is set. The
/// `init(directory:enabled:)` seam lets tests drive it against a temp dir
/// without touching `~/Library/Logs`.
final class FileLogSink: @unchecked Sendable {
    static let shared = FileLogSink(
        directory: FileLogSink.defaultDirectory,
        enabled: AppLog.fileMirroringEnabled
    )

    static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DaveTheDiverSaveEditor", isDirectory: true)
    }

    private let queue = DispatchQueue(label: "\(AppLog.subsystem).filelog")
    private let fileURL: URL?

    /// The file this sink appends to, or `nil` when disabled.
    var currentFileURL: URL? { fileURL }

    init(directory: URL, enabled: Bool) {
        guard enabled else { fileURL = nil; return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("session_\(Self.fileStamp(Date())).log")
        let created = FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)
        fileURL = created ? url : nil
    }

    func write(_ line: String) {
        guard let fileURL else { return }
        let entry = "\(Self.lineStamp(Date())) \(line)\n"
        queue.async {
            guard let data = entry.data(using: .utf8),
                  let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }

    /// Test hook: block until queued writes have flushed to disk.
    func flush() { queue.sync {} }

    // Local-time, locale-stable timestamps built per call (thread-safe, no
    // shared non-Sendable formatter).
    static func fileStamp(_ date: Date) -> String { stamp(date, "yyyyMMdd_HHmmss") }
    static func lineStamp(_ date: Date) -> String { stamp(date, "yyyy-MM-dd HH:mm:ss.SSS") }
    private static func stamp(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f.string(from: date)
    }
}

/// Bundle metadata for the About box and launch logging.
enum AppInfo {
    static var name: String      { string("CFBundleName") ?? "Dave The Diver Save Editor" }
    static var version: String   { string("CFBundleShortVersionString") ?? "1.0" }
    static var build: String     { string("CFBundleVersion") ?? "1" }
    static var copyright: String { string("NSHumanReadableCopyright") ?? "MIT License." }
    private static func string(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
