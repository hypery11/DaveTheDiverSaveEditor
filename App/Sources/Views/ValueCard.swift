// App/Sources/Views/ValueCard.swift
import SwiftUI

/// One editable value: icon + label, a big rounded value that springs on change,
/// the DeltaStrip, and an exact field + Max + Reset.
struct ValueCard: View {
    let model: SaveEditorModel
    let currency: Currency
    let accent: Color

    @State private var bounce = false

    /// The big display groups digits (3,074,847) for readability; the edit field
    /// below keeps the raw digits so it stays parseable.
    private var groupedValue: String {
        guard let v = model.value(currency) else { return "—" }
        return v.formatted(.number.grouping(.automatic))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label(currency.label, systemImage: currency.systemImage)
                .font(Theme.cardTitleFont)
                .foregroundStyle(accent)

            Text(groupedValue)
                .font(Theme.valueFont)
                .foregroundStyle(Theme.Color.textPrimary)
                .contentTransition(.numericText())
                .scaleEffect(bounce ? 1.06 : 1.0, anchor: .leading)
                .animation(Theme.valueSpring, value: bounce)
                .onChange(of: model.value(currency)) { _, _ in
                    bounce = true
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); bounce = false }
                }

            DeltaStrip(model: model, currency: currency)

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Value", text: Binding(
                    get: { model.displayText(currency) },
                    set: { model.applyText(currency, $0) }))
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: Theme.Spacing.exactFieldWidth)
                Button("Max") { model.maximize(currency) }
                    .buttonStyle(.bordered)
                    .tint(Theme.Color.coral)
                Button("Reset") { model.reset(currency) }
                    .buttonStyle(.bordered)
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
