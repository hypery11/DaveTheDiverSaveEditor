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

    private func add() {
        if let id, let count { model.addInventoryItem(itemID: id, count: count) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label {
                Text("Add Inventory Item").foregroundStyle(Theme.Color.textPrimary)
            } icon: {
                Image(systemName: "plus.square.on.square").foregroundStyle(EditorCategory.advanced.accent)
            }
            .font(Theme.cardTitleFont)
            Text("Set or inject a specific item by id and count (power-user).")
                .font(.subheadline).foregroundStyle(Theme.Color.textSecondary)
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Item ID", text: $itemIDText).frame(width: Theme.Spacing.advancedIDFieldWidth)
                    .onSubmit(add)
                TextField("Count", text: $countText).frame(width: Theme.Spacing.advancedCountFieldWidth)
                    .onSubmit(add)
                Button("Add Item", action: add)
                    .buttonStyle(.bordered)
                    .tint(EditorCategory.advanced.accent)
                    .disabled(id == nil || count == nil)
            }
            .textFieldStyle(.roundedBorder).monospacedDigit()
            StatusFooter(text: model.ingredientStatus)
        }
        .cardSurface()
        .disabled(!model.isLoaded)
    }
}
