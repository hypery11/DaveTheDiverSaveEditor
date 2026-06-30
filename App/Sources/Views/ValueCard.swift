// App/Sources/Views/ValueCard.swift
import SwiftUI

/// One editable value: icon + label, a big rounded value that springs on change,
/// the DeltaStrip, and an exact field + Max + Reset.
struct ValueCard: View {
    let model: SaveEditorModel
    let currency: Currency
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label(currency.label, systemImage: currency.systemImage)
                .font(Theme.cardTitleFont)
                .foregroundStyle(accent)

            Text(model.displayText(currency).isEmpty ? "—" : model.displayText(currency))
                .font(Theme.valueFont)
                .foregroundStyle(Theme.Color.textPrimary)
                .contentTransition(.numericText())
                .animation(Theme.valueSpring, value: model.value(currency))

            DeltaStrip(model: model, currency: currency)

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Value", text: Binding(
                    get: { model.displayText(currency) },
                    set: { model.applyText(currency, $0) }))
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: 150)
                Button("Max") { model.maximize(currency) }
                Button("Reset") { model.reset(currency) }
            }
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
