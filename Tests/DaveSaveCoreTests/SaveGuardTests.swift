import Foundation
import Testing
@testable import DaveSaveCore

@Suite struct SaveGuardTests {
    @Test func statusReportsSafetyAndReason() {
        #expect(SaveGuard.Status.safe.isSafe)
        #expect(SaveGuard.Status.safe.blockReason == nil)

        let running = SaveGuard.Status(gameRunning: true, fileOpen: false)
        #expect(!running.isSafe)
        #expect(running.blockReason?.contains("running") == true)

        let open = SaveGuard.Status(gameRunning: false, fileOpen: true)
        #expect(!open.isSafe)
        #expect(open.blockReason?.contains("open") == true)

        // Game-running is reported first when both are true.
        let both = SaveGuard.Status(gameRunning: true, fileOpen: true)
        #expect(both.blockReason?.contains("running") == true)
    }

    @Test func isFileOpenDetectsAHeldHandle() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("guard-\(UUID().uuidString).sav")
        try Data("x".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        #expect(SaveGuard.isFileOpen(url) == true)   // a held fd is detected by lsof -t
    }

    @Test func isFileOpenFalseForMissingFile() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("absent-\(UUID().uuidString).sav")
        #expect(SaveGuard.isFileOpen(url) == false)
    }

    @Test func matchesTheRealGameExecutablePath() {
        // The exact `ps -o comm=` line the running game produces on macOS.
        let game = "/Users/cph/Library/Application Support/Steam/steamapps/common/Dave the Diver/DaveTheDiver.app/Contents/MacOS/DAVE THE DIVER"
        #expect(SaveGuard.matchesGameProcess(in: game))
        // Mixed process list: the game line among unrelated processes.
        #expect(SaveGuard.matchesGameProcess(in: "/sbin/launchd\n\(game)\n/usr/bin/ssh"))
    }

    @Test func doesNotMatchEditorToolsOrOtherGames() {
        #expect(!SaveGuard.matchesGameProcess(in: ""))
        // The editor's own CLI — path contains neither token.
        #expect(!SaveGuard.matchesGameProcess(in: "/Volumes/OWC/dave-the-diver-save-editor/.build/arm64-apple-macosx/debug/dtdcli"))
        // A different Steam game — steamapps but not "dave".
        #expect(!SaveGuard.matchesGameProcess(in: "/Users/x/Library/.../steamapps/common/Hades/Hades.app/Contents/MacOS/Hades"))
    }
}
