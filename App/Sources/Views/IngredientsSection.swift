import SwiftUI

/// Max-Own / Max-All ingredient presets + status feedback.
struct IngredientsSection: View {
    let model: SaveEditorModel

    var body: some View {
        Section("Ingredients") {
            HStack(spacing: 8) {
                Button("Max Own Ingredients") { model.maxOwnIngredients() }
                Button("Max All Ingredients") { model.maxAllIngredients() }
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
