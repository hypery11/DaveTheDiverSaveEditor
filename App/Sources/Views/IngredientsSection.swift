import SwiftUI

/// Ingredient + material presets (main store, branch store, inventory, merman
/// village) with a shared status line for the most recent bulk action.
struct IngredientsSection: View {
    let model: SaveEditorModel

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

            if !model.ingredientStatus.isEmpty {
                Text(model.ingredientStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
