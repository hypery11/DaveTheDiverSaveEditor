import SwiftUI

@main
struct DaveTheDiverSaveEditorApp: App {
    @State private var model = SaveEditorModel()

    var body: some Scene {
        WindowGroup("Dave The Diver Save Editor") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
    }
}
