// App/Sources/Views/DeltaStrip.swift
import SwiftUI

/// −1000 −100 −10 | +10 +100 +1000 for one value. Minus tinted error, plus tinted
/// success, with text-safe glyph colors for contrast; each button adjusts the value.
struct DeltaStrip: View {
    let model: SaveEditorModel
    let currency: Currency
    private let steps: [Int64] = [10, 100, 1000]

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(steps.reversed(), id: \.self) { s in button(-s) }
            Capsule().fill(Theme.Color.separator).frame(width: 1, height: 16)
            ForEach(steps, id: \.self) { s in button(s) }
        }
    }

    private func button(_ delta: Int64) -> some View {
        let positive = delta > 0
        return Button {
            model.adjust(currency, by: delta)
        } label: {
            Text(positive ? "+\(abs(delta))" : "−\(abs(delta))")
                .foregroundStyle(positive ? Theme.Color.successText : Theme.Color.errorText)
                .monospacedDigit()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(positive ? Theme.Color.success : Theme.Color.error)
        .accessibilityLabel(positive
            ? "Add \(abs(delta)) to \(currency.label)"
            : "Subtract \(abs(delta)) from \(currency.label)")
    }
}
