// App/Sources/Views/EditorSidebar.swift
import SwiftUI

struct EditorSidebar: View {
    @Binding var selection: EditorCategory?
    let model: SaveEditorModel
    let onLoad: () -> Void
    let onSave: () -> Void

    /// Only a truly-loaded save shows a filename; otherwise the chip must not imply
    /// a file is open (the detected-but-unloaded save is offered in the empty state).
    private var chipText: String {
        model.isLoaded ? (model.currentFileURL?.lastPathComponent ?? "—") : "No save loaded"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: model.isLoaded ? "doc.fill" : "doc")
                    .foregroundStyle(model.isLoaded ? Theme.Color.ocean : Theme.Color.textSecondary)
                Text(chipText).font(.subheadline).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(model.isLoaded ? Theme.Color.textPrimary : Theme.Color.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Native sidebar: accent lives on the SF Symbol only; the label uses the
            // adaptive label color so it stays legible on cream and flips to white on
            // the (warm ocean) selection — never accent-text-on-system-blue.
            List(EditorCategory.allCases, selection: $selection) { c in
                Label {
                    Text(c.label)
                } icon: {
                    Image(systemName: c.systemImage).foregroundStyle(c.accent)
                }
                .tag(c)
            }
            .listStyle(.sidebar)
            .tint(Theme.Color.ocean)

            Divider()
            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onLoad) { Label("Open…", systemImage: "folder") }
                Spacer()
                Button(action: onSave) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Label("Save", systemImage: "square.and.arrow.up")
                        if model.hasChanges {
                            Circle().fill(Theme.Color.coral)
                                .frame(width: Theme.Spacing.statusDotSize,
                                       height: Theme.Spacing.statusDotSize)
                        }
                    }
                }
                .disabled(!model.isLoaded || !model.hasChanges)
            }
            .padding(Theme.Spacing.md)
        }
    }
}
