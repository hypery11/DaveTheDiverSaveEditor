import SwiftUI

/// Currencies section: one editable row per `Currency`.
struct CurrencySection: View {
    let model: SaveEditorModel

    var body: some View {
        Section("Currencies & Resources") {
            ForEach(Currency.allCases) { currency in
                CurrencyRow(model: model, currency: currency)
            }
        }
    }
}

/// One currency: label · exact-entry field · "Max" preset · "Reset".
struct CurrencyRow: View {
    let model: SaveEditorModel
    let currency: Currency

    var body: some View {
        LabeledContent(currency.label) {
            HStack(spacing: 8) {
                // Derived ("computed") Binding per the contract: reads the
                // model's formatted text, writes parsed input via applyText.
                // Built inside @MainActor `body` so it may call the model.
                TextField(
                    "Value",
                    text: Binding(
                        get: { model.displayText(currency) },
                        set: { model.applyText(currency, $0) }
                    )
                )
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)

                Button("Max") { model.maximize(currency) }
                Button("Reset") { model.reset(currency) }
            }
        }
        .disabled(!model.isLoaded)
    }
}
