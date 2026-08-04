// App/Sources/Views/DeltaStrip.swift
import SwiftUI

/// −1k −100 −10 | +10 +100 +1k for one value. Minus tinted error, plus tinted success,
/// with text-safe glyph colors for contrast; each button adjusts the value.
struct DeltaStrip: View {
    let model: SaveEditorModel
    let currency: Currency
    /// Colour alone must not be the only thing distinguishing add from subtract.
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    private let steps: [Int64] = [10, 100, 1000]

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(steps.reversed(), id: \.self) { s in button(-s) }
            Capsule().fill(Theme.Color.separator)
                .frame(width: 1)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, 2)
            ForEach(steps, id: \.self) { s in button(s) }
        }
        .fixedSize()
    }

    /// Compact, ungrouped label so the strip never truncates in a table row: 1000 → "1k".
    private func compact(_ n: Int64) -> String { n >= 1000 ? "\(n / 1000)k" : "\(n)" }

    /// True when subtracting would clamp the value to 0 rather than subtract. Four of the
    /// seven currencies sit in the low hundreds in a real save, so `−1k` there is not
    /// "subtract 1000", it is "wipe" — from a button a few points away from `−100`.
    private func wouldClampToZero(_ delta: Int64) -> Bool {
        guard delta < 0, let current = model.value(currency) else { return false }
        return current + delta < 0
    }

    private func button(_ delta: Int64) -> some View {
        let positive = delta > 0
        let clamps = wouldClampToZero(delta)
        return Button {
            model.adjust(currency, by: delta)
        } label: {
            Text(verbatim: (positive ? "+" : "−") + compact(abs(delta)))
                // The clamped case has to be styled explicitly. An explicit
                // `foregroundStyle` overrides the dimming `.disabled()` would normally
                // apply to a label, so the button looked identical to a live one and
                // simply did nothing when clicked — worse than the clamping it replaced.
                .foregroundStyle(clamps ? Theme.Color.textSecondary
                                        : (positive ? Theme.Color.successText : Theme.Color.errorText))
                .monospacedDigit()
                // Identical width for all six chips, so the strip's width — and therefore
                // where the controls after it land — stops depending on the locale's font.
                .frame(minWidth: 34)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(clamps ? Theme.Color.slate : (positive ? Theme.Color.success : Theme.Color.error))
        .buttonRepeatBehavior(.enabled)          // press-and-hold ramps instead of one step
        .disabled(clamps)
        .overlay {
            // With Differentiate Without Color on, outline the subtract half so the two
            // triads are distinguishable without relying on red vs green.
            if differentiateWithoutColor && !positive {
                Capsule().strokeBorder(Theme.Color.errorText, lineWidth: 1)
            }
        }
        .help(clamps ? "Would clamp \(currency.label) to 0" : "")
        .accessibilityLabel(positive ? "Add \(abs(delta))" : "Subtract \(abs(delta))")
    }
}
