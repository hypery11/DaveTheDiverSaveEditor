// App/Sources/Views/Detail/RestaurantDetail.swift
import SwiftUI

struct RestaurantDetail: View {
    let model: SaveEditorModel
    private var accent: Color { EditorCategory.restaurant.accent }
    var body: some View {
        ActionCard(title: "Max Owned Ingredients", systemImage: "tray.full.fill",
                   description: "Fill every ingredient you already own (skips perishable aberration fish).",
                   accent: accent, buttonTitle: "Max Own") { model.maxOwnIngredients() }
        ActionCard(title: "Max All Ingredients", systemImage: "tray.2.fill",
                   description: "Fill and inject every DLC-owned ingredient.",
                   accent: accent, buttonTitle: "Max All") { model.maxAllIngredients() }
        ActionCard(title: "Max Branch Store", systemImage: "building.2.fill",
                   description: "Stock the second sushi restaurant's branch counts.",
                   accent: accent, buttonTitle: "Max Branch") { model.maxBranchIngredients() }
        StatusFooter(text: model.ingredientStatus)
    }
}
