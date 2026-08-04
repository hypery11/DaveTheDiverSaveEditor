import Foundation
import Testing
@testable import DaveSaveCore

@Suite("Smoke")
struct SmokeTests {
    @Test("Swift Testing runner executes")
    func runnerExecutes() {
        #expect(DaveSaveCore.version == "0.1.0")
    }

    @Test("reference.sqlite is bundled in Bundle.module")
    func referenceResourceIsPresent() throws {
        let url = try #require(ReferenceResource.url)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
