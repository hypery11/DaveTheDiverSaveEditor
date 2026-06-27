import SwiftUI

@main
struct DaveTheDiverSaveEditorApp: App {
    var body: some Scene {
        WindowGroup("Dave The Diver Save Editor") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Dave The Diver Save Editor")
                .font(.title2.weight(.semibold))
            Text("Scaffold ready.")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 480, minHeight: 320)
        .padding()
    }
}
