// App/Sources/Views/Detail/InventoryDetail.swift
import SwiftUI

struct InventoryDetail: View {
    let model: SaveEditorModel
    private var accent: Color { EditorCategory.inventory.accent }
    var body: some View {
        ActionCard(title: "Max Inventory Items", systemImage: "shippingbox.fill",
                   description: "Raise general materials / crafting parts.",
                   accent: accent, buttonTitle: "Max Items") { model.maxInventoryItems() }
        ActionCard(title: "Max Craft Materials", systemImage: "hammer.fill",
                   description: "Stock fish parts and DREDGE research parts/bones so weapon crafting is unblocked.",
                   accent: accent, buttonTitle: "Max Craft") { model.maxCraftMaterials() }
        ActionCard(title: "Max Merman Village", systemImage: "drop.fill",
                   description: "Fill the Sea People village inventory.",
                   accent: accent, buttonTitle: "Max Village") { model.maxMermanInventory() }
        StatusFooter(text: model.ingredientStatus)
    }
}
