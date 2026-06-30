import SwiftUI

/// Ingredient + material presets (main store, branch store, inventory, merman
/// village, farm seeds, craft materials) plus a power-user "add item by id:count"
/// override, with a shared status line for the most recent bulk action.
struct IngredientsSection: View {
    let model: SaveEditorModel
    @State private var itemIDText = ""
    @State private var countText = ""

    private var parsedItemID: Int? { Int(itemIDText).flatMap { $0 > 0 ? $0 : nil } }
    private var parsedCount: Int? { Int(countText).flatMap { $0 >= 0 ? $0 : nil } }

    var body: some View {
        Section("Ingredients & Materials") {
            HStack(spacing: 8) {
                Button("Max Own Ingredients") { model.maxOwnIngredients() }
                Button("Max All Ingredients") { model.maxAllIngredients() }
                Button("Max Branch Store") { model.maxBranchIngredients() }
            }
            .disabled(!model.isLoaded)

            HStack(spacing: 8) {
                Button("Max Inventory Items") { model.maxInventoryItems() }
                Button("Max Merman Village") { model.maxMermanInventory() }
            }
            .disabled(!model.isLoaded)

            HStack(spacing: 8) {
                Button("Max Seeds") { model.maxSeeds() }
                Button("Max Craft Materials") { model.maxCraftMaterials() }
            }
            .disabled(!model.isLoaded)

            // Power-user override: add or set a specific inventory item by id and count.
            HStack(spacing: 8) {
                TextField("Item ID", text: $itemIDText)
                    .frame(width: 120)
                TextField("Count", text: $countText)
                    .frame(width: 90)
                Button("Add Item") {
                    if let id = parsedItemID, let c = parsedCount {
                        model.addInventoryItem(itemID: id, count: c)
                    }
                }
                .disabled(parsedItemID == nil || parsedCount == nil)
            }
            .textFieldStyle(.roundedBorder)
            .monospacedDigit()
            .disabled(!model.isLoaded)

            if !model.ingredientStatus.isEmpty {
                Text(model.ingredientStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
