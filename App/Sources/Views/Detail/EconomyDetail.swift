// App/Sources/Views/Detail/EconomyDetail.swift
import SwiftUI

struct EconomyDetail: View {
    let model: SaveEditorModel
    var body: some View {
        ForEach(Currency.allCases) { c in
            ValueCard(model: model, currency: c, accent: EditorCategory.economy.accent)
        }
    }
}
