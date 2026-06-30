import SwiftUI
import DaveSaveCore

@main
struct DaveTheDiverSaveEditorApp: App {
    @State private var model: SaveEditorModel

    init() {
        // ReferenceDB powers Max-Own / Max-All. If it can't load we still run;
        // ingredient actions report unavailability through `ingredientStatus`.
        let referenceDB = try? ReferenceDB.bundled()
        _model = State(initialValue: SaveEditorModel(
            referenceDB: referenceDB,
            fileManager: .default,
            home: nil,
            safetyCheck: { SaveGuard.check(saveURL: $0) }
        ))
        AppLog.app.info(
            "Launched \(AppInfo.name) v\(AppInfo.version) (\(AppInfo.build)); "
            + "referenceDB=\(referenceDB == nil ? "unavailable" : "loaded"); "
            + "fileLog=\(AppLog.fileMirroringEnabled)"
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear { model.detectLatestSave() }
        }
        .windowResizability(.contentSize)
        .commands {
            SaveEditorCommands(model: model)
        }

        Window("About \(AppInfo.name)", id: AboutView.windowID) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// File + App menu commands. Holds the model by reference; all actions run on
/// the main actor (Commands.body is `@MainActor`, matching the `@MainActor`
/// model).
struct SaveEditorCommands: Commands {
    let model: SaveEditorModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // Replace the standard "About" item → open our credits window.
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppInfo.name)") {
                openWindow(id: AboutView.windowID)
            }
        }

        // File ▸ Open… (⌘O) and Load Latest Save (⌘L), after the New group.
        CommandGroup(after: .newItem) {
            Button("Open Save…") {
                SavePanel.present(model: model)
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Load Latest Save") {
                model.detectLatestSave()
                model.loadDetected()
            }
            .keyboardShortcut("l", modifiers: .command)

            Divider()
        }

        // File ▸ Save (⌘S) → request preview+confirm sheet via model flag.
        // ContentView observes `model.requestWrite` and presents the sheet;
        // the actual write only happens after the user confirms in the preview.
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                model.requestWrite = true
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!model.isLoaded || !model.hasChanges)
        }
    }
}

/// NSOpenPanel wrapper. Lives in the App layer (UI), not the model. `.sav`
/// files have no registered UTType, so the panel is left unrestricted to avoid
/// greying them out; it pre-points at the detected save directory when known.
enum SavePanel {
    @MainActor
    static func present(model: SaveEditorModel) {
        let panel = NSOpenPanel()
        panel.title = "Open Dave the Diver Save"
        panel.message = "Choose a GameSave\u{2026}_GD.sav or m_\u{2026}.sav file."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = true
        if let directory = model.detected?.directoryURL {
            panel.directoryURL = directory
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.load(url: url)
    }
}
