// App/Sources/Views/Detail/InventoryDetail.swift
import SwiftUI

struct InventoryDetail: View {
    let model: SaveEditorModel
    private var accent: Color { EditorCategory.inventory.accent }
    var body: some View {
        ActionCard(title: "Max Inventory Items", systemImage: "shippingbox.fill",
                   description: "Raise general materials / crafting parts.",
                   accent: accent, buttonTitle: "Max Items", isEnabled: model.isLoaded) { model.maxInventoryItems() }
        ActionCard(title: "Max Craft Materials", systemImage: "hammer.fill",
                   description: "Stock fish parts and DREDGE research parts/bones so weapon crafting is unblocked.",
                   accent: accent, buttonTitle: "Max Craft", isEnabled: model.isLoaded) { model.maxCraftMaterials() }
        ActionCard(title: "Max Merman Village", systemImage: "drop.fill",
                   description: "Fill the Sea People village inventory.",
                   accent: accent, buttonTitle: "Max Village", isEnabled: model.isLoaded) { model.maxMermanInventory() }
        ActionCard(title: "Max Farm Seeds", systemImage: "leaf.fill",
                   description: "Fill every owned seed / produce stack in the home farm.",
                   accent: Theme.Color.leaf, buttonTitle: "Max Seeds", isEnabled: model.isLoaded) { model.maxSeeds() }
        StatusFooter(model: model)
        ItemBrowser(model: model)
    }
}
