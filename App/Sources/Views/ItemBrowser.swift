// App/Sources/Views/ItemBrowser.swift
import SwiftUI

/// Browse the save's inventory by name and edit any single item's count inline —
/// so you're not limited to bulk "Max" and don't need to know internal item IDs.
struct ItemBrowser: View {
    let model: SaveEditorModel
    @State private var query = ""

    private var rows: [SaveEditorModel.InventoryRow] {
        let all = model.inventoryRows()
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) || String($0.id).contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label {
                Text("Browse & Edit Items").foregroundStyle(Theme.Color.textPrimary)
            } icon: {
                Image(systemName: "list.bullet.rectangle").foregroundStyle(EditorCategory.inventory.accent)
            }
            .font(Theme.cardTitleFont)

            TextField("Search items by name…", text: $query)
                .textFieldStyle(.roundedBorder)

            let items = rows
            if items.isEmpty {
                Text(query.isEmpty ? "This save has no inventory items." : "No items match “\(query)”.")
                    .font(.callout).foregroundStyle(Theme.Color.textSecondary)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(items) { row in
                        ItemBrowserRow(model: model, row: row)
                        Divider()
                    }
                }
            }
        }
        .cardSurface()
        .disabled(!model.isLoaded)
    }
}

private struct ItemBrowserRow: View {
    let model: SaveEditorModel
    let row: SaveEditorModel.InventoryRow
    @State private var setText = ""

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).foregroundStyle(Theme.Color.textPrimary)
                Text(verbatim: "#\(row.id)").font(.caption.monospaced()).foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer(minLength: Theme.Spacing.md)
            Text("\(row.count)")
                .monospacedDigit().foregroundStyle(Theme.Color.textSecondary)
                .frame(minWidth: 44, alignment: .trailing)
            TextField("set", text: $setText)
                .textFieldStyle(.roundedBorder).monospacedDigit().frame(width: 64)
                .onSubmit(apply)
                .accessibilityLabel("Set \(row.name) count")
            Button("Set", action: apply)
                .buttonStyle(.bordered)
                .disabled(Int(setText) == nil)
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func apply() {
        guard let c = Int(setText), c >= 0 else { return }
        model.addInventoryItem(itemID: row.id, count: c)
        setText = ""
    }
}
