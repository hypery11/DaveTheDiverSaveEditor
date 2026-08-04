import Testing
@testable import DaveTheDiverSaveEditor

/// Proves the unit-test target links and can `@testable import` the app module.
///
/// `@MainActor` is required, not decorative: SwiftUI's `App` has a main-actor-isolated
/// `init()`, and constructing one from a nonisolated context is a hard compile error on
/// Xcode 16.x — which is what CI builds with. Without it this file fails to compile there
/// while building fine on newer toolchains.
@MainActor
@Suite struct ScaffoldSmokeTests {
    @Test func appModuleIsImportable() {
        let app = DaveTheDiverSaveEditorApp()
        #expect(type(of: app) == DaveTheDiverSaveEditorApp.self)
    }
}
