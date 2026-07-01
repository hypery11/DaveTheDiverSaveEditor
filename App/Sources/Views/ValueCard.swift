// App/Sources/Views/ValueCard.swift
import SwiftUI

/// One editable value: icon + label + caption, a big rounded number (the focal display,
/// grouped and springing on change), the ±DeltaStrip, and a "Set exact…" field + Max /
/// Reset. The field is a real input (empty placeholder), not a second copy of the value.
struct ValueCard: View {
    let model: SaveEditorModel
    let currency: Currency
    let accent: Color

    @State private var setText = ""
    @State private var bounce = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 34

    private var groupedValue: String {
        model.value(currency).map { $0.formatted(.number.grouping(.automatic)) } ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(currency.label).foregroundStyle(Theme.Color.textPrimary)
                } icon: {
                    Image(systemName: currency.systemImage).foregroundStyle(accent)
                }
                .font(Theme.cardTitleFont)
                Text(currency.caption)
                    .font(.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            Text(groupedValue)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.Color.textPrimary)
                .contentTransition(.numericText())
                .scaleEffect(!reduceMotion && bounce ? 1.06 : 1.0, anchor: .leading)
                .animation(reduceMotion ? nil : Theme.valueSpring, value: bounce)
                .accessibilityLabel("\(currency.label): \(groupedValue)")
                .onChange(of: model.value(currency)) { _, _ in
                    guard !reduceMotion else { return }
                    bounce = true
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); bounce = false }
                }

            DeltaStrip(model: model, currency: currency)

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Set exact…", text: $setText)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: Theme.Spacing.exactFieldWidth)
                    .onSubmit(commitSet)
                    .accessibilityLabel("Set \(currency.label) to an exact value")
                Button("Set", action: commitSet)
                    .buttonStyle(.bordered)
                    .disabled(Int64(setText) == nil)
                Spacer(minLength: Theme.Spacing.sm)
                Button("Max") { model.maximize(currency) }
                    .buttonStyle(.bordered)
                    .tint(Theme.Color.coral)
                    .accessibilityLabel("Set \(currency.label) to maximum")
                Button("Reset") { model.reset(currency) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Reset \(currency.label)")
            }
        }
        .cardSurface()
        .disabled(!model.isLoaded)
    }

    private func commitSet() {
        guard !setText.isEmpty else { return }
        model.applyText(currency, setText)
        setText = ""
    }
}
