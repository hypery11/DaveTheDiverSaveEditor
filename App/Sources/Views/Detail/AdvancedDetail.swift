// App/Sources/Views/Detail/AdvancedDetail.swift
import SwiftUI

/// Shared status line used by the bulk-action detail panes.
struct StatusFooter: View {
    let text: String
    var body: some View {
        if !text.isEmpty {
            Text(text).font(.callout).foregroundStyle(Theme.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Power-user override: add/set a specific InventoryItemSlot by id and count.
struct AdvancedDetail: View {
    let model: SaveEditorModel
    @State private var itemIDText = ""
    @State private var countText = ""
    private var id: Int? { Int(itemIDText).flatMap { $0 > 0 ? $0 : nil } }
    private var count: Int? { Int(countText).flatMap { $0 >= 0 ? $0 : nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Add Inventory Item", systemImage: "plus.square.on.square")
                .font(Theme.cardTitleFont).foregroundStyle(EditorCategory.advanced.accent)
            Text("Set or inject a specific item by id and count (power-user).")
                .font(.subheadline).foregroundStyle(Theme.Color.textSecondary)
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Item ID", text: $itemIDText).frame(width: Theme.Spacing.advancedIDFieldWidth)
                TextField("Count", text: $countText).frame(width: Theme.Spacing.advancedCountFieldWidth)
                Button("Add Item") { if let id, let count { model.addInventoryItem(itemID: id, count: count) } }
                    .buttonStyle(.bordered)
                    .tint(EditorCategory.advanced.accent)
                    .disabled(id == nil || count == nil)
            }
            .textFieldStyle(.roundedBorder).monospacedDigit()
            StatusFooter(text: model.ingredientStatus)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.separator)
        }
        .disabled(!model.isLoaded)
    }
}
