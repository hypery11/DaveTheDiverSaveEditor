import SwiftUI

/// Root editor screen. Thin: owns no save/file logic, only composes sections
/// and drives the NSOpenPanel + write-flow chrome (toolbar, sheet, alert).
struct ContentView: View {
    @Bindable var model: SaveEditorModel

    // ── Added by Task 5 ───────────────────────────────────────────────
    @State private var showingPreview = false
    // ──────────────────────────────────────────────────────────────────

    var body: some View {
        Form {
            CurrencySection(model: model)
            IngredientsSection(model: model)
            FileInfoSection(model: model, onLoadFile: loadSaveFile)
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 540)
        // ── Added by Task 5: write-flow chrome ───────────────────────
        .toolbar {
            ToolbarItemGroup {
                Button {
                    loadSaveFile()
                } label: {
                    Label("Load Save File…", systemImage: "folder")
                }
                // Keyboard shortcut owned by File ▸ Open… menu command (⌘O).
                .help("Choose a Dave the Diver save file to load.")

                Button {
                    showingPreview = true
                } label: {
                    Label("Write Save File", systemImage: "square.and.arrow.down")
                }
                // Keyboard shortcut owned by File ▸ Save menu command (⌘S).
                .disabled(!model.hasChanges)
                .help("Review pending changes and write them to the save file.")
            }
        }
        .sheet(isPresented: $showingPreview) {
            ChangePreviewView(model: model)
        }
        // Menu ⌘S sets model.requestWrite; observe here to present the sheet.
        .onChange(of: model.requestWrite) { _, newValue in
            if newValue {
                showingPreview = true
                model.requestWrite = false
            }
        }
        .alert(item: $model.alert) { appAlert in
            if let url = appAlert.revealURL {
                return Alert(
                    title: Text(appAlert.title),
                    message: Text(appAlert.message),
                    primaryButton: .default(Text("Reveal Backup in Finder")) {
                        model.revealInFinder(url)
                    },
                    secondaryButton: .default(Text("OK"))
                )
            } else {
                return Alert(
                    title: Text(appAlert.title),
                    message: Text(appAlert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        // ─────────────────────────────────────────────────────────────
    }

    // ── Added by Task 5 ───────────────────────────────────────────────
    /// Open the panel pre-pointed at the detected save folder and hand any
    /// chosen file to the model. All file/parse logic stays in the model.
    private func loadSaveFile() {
        if let url = FileDialogs.openSaveFile(startDirectory: model.detected?.directoryURL) {
            model.load(url: url)
        }
    }
    // ──────────────────────────────────────────────────────────────────
}
