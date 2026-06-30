// App/Sources/Views/EditorSidebar.swift
import SwiftUI

struct EditorSidebar: View {
    @Binding var selection: EditorCategory?
    let model: SaveEditorModel
    let onLoad: () -> Void
    let onSave: () -> Void

    private var saveName: String {
        model.currentFileURL?.lastPathComponent ?? model.detected?.fileURL.lastPathComponent ?? "No save loaded"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: model.isLoaded ? "doc.fill" : "doc")
                    .foregroundStyle(model.isLoaded ? Theme.Color.ocean : Theme.Color.textSecondary)
                Text(saveName).font(.subheadline).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(Theme.Color.textPrimary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            List(EditorCategory.allCases, selection: $selection) { c in
                Label(c.label, systemImage: c.systemImage)
                    .foregroundStyle(c.accent)
                    .tag(c)
            }

            Divider()
            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onLoad) { Label("Load", systemImage: "folder") }
                Spacer()
                Button(action: onSave) {
                    Label("Save", systemImage: "square.and.arrow.down")
                    if model.hasChanges {
                        Circle().fill(Theme.Color.coral).frame(width: 7, height: 7)
                    }
                }
                .disabled(!model.isLoaded || !model.hasChanges)
            }
            .padding(Theme.Spacing.md)
        }
    }
}
