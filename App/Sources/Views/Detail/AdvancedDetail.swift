// App/Sources/Views/Detail/AdvancedDetail.swift
import SwiftUI
import DaveSaveCore

/// Add or inject an inventory item — searched by NAME (no need to know internal IDs),
/// with a raw numeric ID still accepted. Rendered as plain rows inside the Advanced section.
struct AdvancedDetail: View {
    let model: SaveEditorModel
    @State private var query = ""
    @State private var picked: ItemMatch? = nil
    @State private var countText = ""
    @State private var results: [ItemMatch] = []

    private func computeResults() -> [ItemMatch] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var out: [ItemMatch] = []
        if let raw = Int(q), raw > 0 { out.append(ItemMatch(id: raw, name: model.itemName(for: raw))) }
        out.append(contentsOf: model.searchItems(q).filter { m in !out.contains(where: { $0.id == m.id }) })
        return Array(out.prefix(12))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Search an item by name (or a numeric ID), pick it, then set a count.")
                .font(.subheadline).foregroundStyle(Theme.Color.textSecondary)

            if let item = picked {
                HStack(spacing: Theme.Spacing.sm) {
                    Label {
                        Text(verbatim: "\(item.name)  ·  #\(item.id)")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundStyle(Theme.Color.success)
                    Spacer(minLength: Theme.Spacing.md)
                    TextField("Count", text: $countText)
                        .textFieldStyle(.roundedBorder).monospacedDigit().frame(width: 90)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .buttonStyle(.borderedProminent).tint(Theme.Color.slate)
                        .disabled(Int(countText) == nil)
                    Button("Clear") { reset() }.buttonStyle(.bordered)
                }
            } else {
                TextField("Search item name or ID…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: query) { _, _ in results = computeResults() }
                if results.isEmpty {
                    if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("No matches.").font(.callout).foregroundStyle(Theme.Color.textSecondary)
                    }
                } else {
                    ForEach(results) { m in
                        Button { picked = m } label: {
                            HStack {
                                Text(m.name).foregroundStyle(Theme.Color.textPrimary)
                                Spacer()
                                Text(verbatim: "#\(m.id)").font(.caption.monospaced()).foregroundStyle(Theme.Color.textSecondary)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        .disabled(!model.isLoaded)
    }

    private func add() {
        guard let item = picked, let c = Int(countText), c >= 0 else { return }
        model.addInventoryItem(itemID: item.id, count: c)
        reset()
    }

    private func reset() {
        picked = nil; countText = ""; query = ""
    }
}
