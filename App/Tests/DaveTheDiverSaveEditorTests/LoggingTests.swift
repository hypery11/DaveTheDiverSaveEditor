import Testing
import Foundation
@testable import DaveTheDiverSaveEditor

struct LoggingTests {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DTDLogTests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func mirrorsLinesToFileWhenEnabled() throws {
        let dir = tempDir()
        let sink = FileLogSink(directory: dir, enabled: true)
        sink.write("[INFO] [io] loaded save: gold=42")
        sink.write("[NOTICE] [io] backup written")
        sink.flush()

        let url = try #require(sink.currentFileURL)
        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents.contains("loaded save: gold=42"))
        #expect(contents.contains("backup written"))
        #expect(contents.split(separator: "\n").count == 2)   // two appended lines
        try? FileManager.default.removeItem(at: dir)
    }

    @Test func createsNoFileWhenDisabled() {
        let dir = tempDir()
        let sink = FileLogSink(directory: dir, enabled: false)
        sink.write("ignored")
        sink.flush()
        #expect(sink.currentFileURL == nil)
        #expect(FileManager.default.fileExists(atPath: dir.path) == false)
    }

    @Test func fileStampIsLocaleStableFixedWidth() {
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        let stamp = FileLogSink.fileStamp(date)
        #expect(stamp.count == 15)        // yyyyMMdd_HHmmss
        #expect(stamp.contains("_"))
    }
}
