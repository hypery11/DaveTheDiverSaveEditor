import Foundation

/// Pre-write safety checks. Writing a save while the game is running — or while another
/// process holds the file open — risks the edit being overwritten on the game's next
/// save, or a torn read. The editor consults this before every write. Foundation-only
/// (no AppKit) so both the app and the `dtdcli` tool share it.
public enum SaveGuard {

    public struct Status: Equatable, Sendable {
        public let gameRunning: Bool
        public let fileOpen: Bool

        public init(gameRunning: Bool, fileOpen: Bool) {
            self.gameRunning = gameRunning
            self.fileOpen = fileOpen
        }

        public var isSafe: Bool { !gameRunning && !fileOpen }

        /// A user-facing reason the write is unsafe, or nil when safe. Game-running is
        /// reported first: it is the more dangerous and more common condition.
        public var blockReason: String? {
            if gameRunning {
                return "Dave the Diver is still running. Quit the game fully (⌘Q) before writing — a running game overwrites your edits on its next save."
            }
            if fileOpen {
                return "The save file is currently open by another process. If you just quit the game, wait a moment and try again."
            }
            return nil
        }

        /// An explicitly-safe status, for tests/previews that should never block.
        public static let safe = Status(gameRunning: false, fileOpen: false)
    }

    /// Whether it is safe to write `saveURL` right now.
    public static func check(saveURL: URL) -> Status {
        Status(gameRunning: isGameRunning(), fileOpen: isFileOpen(saveURL))
    }

    /// True if a Dave the Diver game process is running. Matches a process whose
    /// executable path is under a Steam `steamapps` directory and mentions "dave"
    /// (e.g. `…/steamapps/common/Dave the Diver/…/DAVE THE DIVER`). Uses the executable
    /// path (`ps -o comm`), not arguments, so it never matches the editor's own tools.
    public static func isGameRunning() -> Bool {
        guard let out = run("/bin/ps", ["-axo", "comm="]) else { return false }
        return matchesGameProcess(in: out)
    }

    /// Pure predicate over `ps -o comm=` output: true if any line is a Dave the Diver
    /// game executable — under a Steam `steamapps` directory and mentioning "dave".
    /// Matching the executable path (not arguments) is what keeps the editor's own
    /// tools, whose paths contain neither token, from matching. Exposed for testing.
    static func matchesGameProcess(in psOutput: String) -> Bool {
        psOutput.split(separator: "\n").contains { line in
            let l = line.lowercased()
            return l.contains("steamapps") && l.contains("dave")
        }
    }

    /// True if `url` is currently held open by any process (per `lsof -t`). Returns false
    /// if the file is absent or `lsof` is unavailable. `-t` prints only PIDs (no header),
    /// so non-empty output means at least one process has it open.
    public static func isFileOpen(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        guard let out = run("/usr/sbin/lsof", ["-t", "--", url.path]) else { return false }
        return !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Run a tool and capture stdout, or nil on failure. Never throws.
    private static func run(_ launchPath: String, _ args: [String]) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
