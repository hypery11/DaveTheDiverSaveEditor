// App/Sources/Views/ValueCard.swift
import SwiftUI

/// One editable value. The big rounded number IS the edit control: it shows grouped
/// digits (3,074,847) at rest and raw digits while focused, committing on Return/blur.
/// Below it: the ±DeltaStrip and Max / Reset. The number springs on any change.
struct ValueCard: View {
    let model: SaveEditorModel
    let currency: Currency
    let accent: Color

    @State private var draft = ""
    @State private var bounce = false
    @FocusState private var editing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var groupedValue: String {
        model.value(currency).map { $0.formatted(.number.grouping(.automatic)) } ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label {
                Text(currency.label).foregroundStyle(Theme.Color.textPrimary)
            } icon: {
                Image(systemName: currency.systemImage).foregroundStyle(accent)
            }
            .font(Theme.cardTitleFont)

            TextField("", text: $draft)
                .focused($editing)
                .textFieldStyle(.plain)
                .font(Theme.valueFont)
                .foregroundStyle(Theme.Color.textPrimary)
                .scaleEffect(!reduceMotion && bounce ? 1.06 : 1.0, anchor: .leading)
                .animation(reduceMotion ? nil : Theme.valueSpring, value: bounce)
                .accessibilityLabel("\(currency.label) value")
                .onAppear { draft = groupedValue }
                .onSubmit { commit() }
                .onChange(of: editing) { _, nowEditing in
                    if nowEditing { draft = model.displayText(currency) }  // raw digits to edit
                    else { commit() }
                }
                .onChange(of: model.value(currency)) { _, _ in
                    if !editing { draft = groupedValue }
                    guard !reduceMotion else { return }
                    bounce = true
                    Task { try? await Task.sleep(nanoseconds: 350_000_000); bounce = false }
                }

            DeltaStrip(model: model, currency: currency)

            HStack(spacing: Theme.Spacing.sm) {
                Button("Max") { model.maximize(currency) }
                    .buttonStyle(.bordered)
                    .tint(Theme.Color.coral)
                    .accessibilityLabel("Set \(currency.label) to maximum")
                Button("Reset") { model.reset(currency) }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Reset \(currency.label)")
                Spacer()
            }
        }
        .cardSurface()
        .disabled(!model.isLoaded)
    }

    /// Push the draft into the model (applyText clamps + ignores junk), then reflect the
    /// committed value back as grouped digits.
    private func commit() {
        model.applyText(currency, draft)
        draft = groupedValue
    }
}
