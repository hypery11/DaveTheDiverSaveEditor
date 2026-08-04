import AppKit
import UniformTypeIdentifiers

/// Thin AppKit wrapper around `NSOpenPanel` for choosing a save file.
/// Contains no save/parse logic — it only collects a URL for the model.
enum FileDialogs {

    /// Run a modal open panel for a single Dave the Diver `.sav` file.
    /// `startDirectory` pre-points the panel at the auto-detected save folder
    /// (`model.detected?.directoryURL`). Returns the chosen URL, or `nil` on
    /// cancel. Must run on the main actor (NSOpenPanel is main-thread only).
    @MainActor
    static func openSaveFile(startDirectory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.title = "Load Save File"
        panel.prompt = "Load Save"
        panel.message = "Choose a Dave the Diver save file (GameSave…_GD.sav or m_…sav)."
        if let startDirectory {
            panel.directoryURL = startDirectory
        }
        // Surface `.sav` first, but allow all files so unusual names/slots
        // are still selectable (spec §7 "allowed types: .sav and all files").
        var types: [UTType] = [.data]
        if let sav = UTType(filenameExtension: "sav") {
            types.insert(sav, at: 0)
        }
        panel.allowedContentTypes = types
        panel.allowsOtherFileTypes = true

        return panel.runModal() == .OK ? panel.url : nil
    }
}
