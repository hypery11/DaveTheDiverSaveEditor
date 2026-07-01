// App/Sources/Views/EditorSidebar.swift
import SwiftUI

/// Sidebar: a loaded-save chip + the category list. Load/Save live in the window
/// toolbar (native), so the sidebar footer is gone.
struct EditorSidebar: View {
    @Binding var selection: EditorCategory?
    let model: SaveEditorModel

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
            // the (warm ocean) selection.
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
        }
    }
}
