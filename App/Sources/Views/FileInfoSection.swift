import SwiftUI
import DaveSaveCore

/// Shows the loaded save's path, or an empty state with load actions.
struct FileInfoSection: View {
    let model: SaveEditorModel
    var onLoadFile: () -> Void = {}

    var body: some View {
        Section("Save File") {
            if model.isLoaded {
                LabeledContent("Path") {
                    Text(model.currentFileURL?.path ?? "")
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            } else {
                EmptyStateView(model: model, onLoadFile: onLoadFile)
            }
        }
    }
}

/// Disabled-not-nagging empty state: surfaces the detected newest save and
/// the two ways to load one.
struct EmptyStateView: View {
    let model: SaveEditorModel
    var onLoadFile: () -> Void = {}

    var body: some View {
        ContentUnavailableView {
            Label("No Save Loaded", systemImage: "tray.and.arrow.down")
        } description: {
            DetectedSaveDescription(detected: model.detected)
        } actions: {
            if model.detected != nil {
                Button("Load Latest Save") { model.loadDetected() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Load Save File…") { onLoadFile() }
        }
    }
}

/// Narrow-input description of the auto-detected save (or a prompt to pick one).
struct DetectedSaveDescription: View {
    let detected: SaveCandidate?

    var body: some View {
        if let detected {
            Text("Detected latest save: \(detected.fileURL.lastPathComponent) — modified \(detected.modified.formatted(date: .abbreviated, time: .shortened))")
        } else {
            Text("No Dave the Diver save detected. Choose a save file to begin editing.")
        }
    }
}
