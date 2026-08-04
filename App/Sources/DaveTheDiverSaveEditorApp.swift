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
                // Pinned only when the screenshot script asks for it; nil is a
                // pass-through, so a normal launch is untouched.
                .frame(width: Snapshot.contentSize?.width, height: Snapshot.contentSize?.height)
                .onAppear {
                    // Appearance is applied here, NOT in init(): touching
                    // NSApplication.shared during App.init() instantiates NSApplication
                    // before SwiftUI wires up its scenes, and the WindowGroup then never
                    // creates a window at all.
                    Snapshot.applyAppearance()
                    // Snapshot/UI-test seam: `-snapshot-fixture <path>` preloads a save so
                    // an automated capture sees populated rows (no keystrokes needed).
                    if let fixture = Snapshot.fixture {
                        model.load(url: URL(fileURLWithPath: fixture))
                    } else {
                        model.detectLatestSave()
                    }
                    model.offerSupportAtLaunch()
                }
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

        // Help ▸ … — the only support path most users will ever find. Copy Diagnostics
        // exists because the audience largely isn't on GitHub and often isn't writing in
        // English; a paste-able block works on Nexus, Bilibili or DC Inside just as well.
        CommandGroup(replacing: .help) {
            Button("DiveSaveEd Help") {
                NSWorkspace.shared.open(SupportLinks.faq)
            }
            // `CommandGroup(replacing: .help)` discards SwiftUI's default Help item *and its
            // ⌘? binding*, which was never restored — so the shortcut the HIG names for this
            // exact item did nothing.
            .keyboardShortcut("?", modifiers: .command)

            Button("Report a Problem…") {
                // Clipboard first, always. If GitHub's prefill parameters change or the
                // payload is ever over-length, the report degrades to "paste this" instead
                // of being lost.
                Diagnostics.copyToPasteboard(for: model)
                NSWorkspace.shared.open(IssueReport.url(diagnostics: Diagnostics.text(for: model)))
            }

            // For an app whose pitch is "MIT, go read it", a one-click path to the source is
            // genuinely help-related — and it is the cheapest trust win available.
            Button("Source Code") {
                NSWorkspace.shared.open(SupportLinks.source)
            }

            Button("Support the Project…") {
                NSWorkspace.shared.open(SupportLinks.support)
            }

            Divider()
            Button("Copy Diagnostics") {
                Diagnostics.copyToPasteboard(for: model)
            }
        }

        // Edit ▸ Undo / Redo. Without this group the Edit menu's Undo binds to the focused
        // text field's own undo, so ⌘Z after Run All Fills did nothing — on the platform
        // where ⌘Z is the most reflexive key there is. The model's stack covers currency
        // edits and bulk fills alike, so one pair of items serves both.
        CommandGroup(replacing: .undoRedo) {
            Button(model.undoLabel.map { String(localized: "Undo \($0)") } ?? String(localized: "Undo")) {
                model.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!model.canUndo)

            Button(model.redoLabel.map { String(localized: "Redo \($0)") } ?? String(localized: "Redo")) {
                model.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!model.canRedo)
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
