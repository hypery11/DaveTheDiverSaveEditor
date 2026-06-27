import Testing
@testable import DaveTheDiverSaveEditor

/// Proves the unit-test target links and can `@testable import` the app module.
/// Real `SaveEditorModelTests` are added in a later task.
@Suite struct ScaffoldSmokeTests {
    @Test func appModuleIsImportable() {
        let app = DaveTheDiverSaveEditorApp()
        #expect(type(of: app) == DaveTheDiverSaveEditorApp.self)
    }
}
