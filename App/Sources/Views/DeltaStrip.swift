// App/Sources/Views/DeltaStrip.swift
import SwiftUI

/// −1000 −100 −10 | +10 +100 +1000 for one value. Minus tinted error, plus tinted success.
struct DeltaStrip: View {
    let model: SaveEditorModel
    let currency: Currency
    private let steps: [Int64] = [10, 100, 1000]

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(steps.reversed(), id: \.self) { s in
                button(-s, tint: Theme.Color.error)
            }
            Divider().frame(height: 18)
            ForEach(steps, id: \.self) { s in
                button(s, tint: Theme.Color.success)
            }
        }
    }

    private func button(_ delta: Int64, tint: Color) -> some View {
        Button(delta > 0 ? "+\(abs(delta))" : "−\(abs(delta))") {
            model.adjust(currency, by: delta)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tint)
        .monospacedDigit()
    }
}
