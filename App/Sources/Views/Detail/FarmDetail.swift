// App/Sources/Views/Detail/FarmDetail.swift
import SwiftUI

struct FarmDetail: View {
    let model: SaveEditorModel
    var body: some View {
        ActionCard(title: "Max Seeds", systemImage: "leaf.fill",
                   description: "Fill every owned seed / produce stack in the home farm.",
                   accent: EditorCategory.farm.accent, buttonTitle: "Max Seeds") { model.maxSeeds() }
        StatusFooter(text: model.ingredientStatus)
    }
}
