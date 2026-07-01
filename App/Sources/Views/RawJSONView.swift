// App/Sources/Views/RawJSONView.swift
import SwiftUI
import AppKit

/// Read-only inspector for the entire decoded save. Deliberately NOT editable:
/// hand-editing raw JSON could set progression flags that unlock content out of
/// order or soft-lock a run, so this view only lets you read, search, and copy —
/// structured edits go through the typed controls that know the safe ranges.
struct RawJSONView: View {
    let model: SaveEditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var allLines: [Line] = []

    struct Line: Identifiable { let id: Int; let text: String }

    private var filtered: [Line] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allLines }
        return allLines.filter { $0.text.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            let rows = filtered
            Group {
                if rows.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "Nothing loaded" : "No matches for “\(query)”",
                                           systemImage: "curlybraces")
                } else {
                    List(rows) { line in
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            Text(verbatim: "\(line.id)")
                                .font(.caption.monospaced()).foregroundStyle(Theme.Color.textSecondary)
                                .frame(width: 52, alignment: .trailing)
                            Text(line.text)
                                .font(.body.monospaced())
                                .foregroundStyle(Theme.Color.textPrimary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $query, prompt: "Search keys or values…")
            .navigationTitle("Raw Save · read-only")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Copy All", systemImage: "doc.on.doc") { copyAll() }
                }
            }
        }
        .frame(minWidth: 660, minHeight: 560)
        .task(id: model.isLoaded) {
            allLines = model.rawJSON()
                .split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .map { Line(id: $0.offset + 1, text: String($0.element)) }
        }
    }

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.rawJSON(), forType: .string)
    }
}
