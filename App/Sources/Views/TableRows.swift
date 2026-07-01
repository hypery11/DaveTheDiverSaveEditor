// App/Sources/Views/TableRows.swift
import SwiftUI

/// Section header for the single-table layout: accent icon + title, pinned on scroll.
struct SectionHeader: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage).foregroundStyle(accent)
            Text(title).font(Theme.cardTitleFont).foregroundStyle(Theme.Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}

/// One compact currency row: icon · name · value · ±strip · set · Max · Reset.
struct EconomyRow: View {
    let model: SaveEditorModel
    let currency: Currency
    @State private var setText = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    private var accent: Color { EditorCategory.economy.accent }
    private var grouped: String {
        model.value(currency).map { $0.formatted(.number.grouping(.automatic)) } ?? "—"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: currency.systemImage).foregroundStyle(accent).frame(width: 20)
            Text(currency.label)
                .frame(width: 130, alignment: .leading)
                .foregroundStyle(Theme.Color.textPrimary)
                .help(currency.caption)
            Text(grouped)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(width: 116, alignment: .trailing)
                .contentTransition(.numericText())
                .scaleEffect(!reduceMotion && bounce ? 1.05 : 1.0)
                .animation(reduceMotion ? nil : Theme.valueSpring, value: bounce)
                .onChange(of: model.value(currency)) { _, _ in
                    guard !reduceMotion else { return }
                    bounce = true
                    Task { try? await Task.sleep(nanoseconds: 300_000_000); bounce = false }
                }
                .accessibilityLabel("\(currency.label): \(grouped)")

            DeltaStrip(model: model, currency: currency)

            TextField("set", text: $setText)
                .textFieldStyle(.roundedBorder).monospacedDigit().frame(width: 68)
                .onSubmit(commit)
                .accessibilityLabel("Set \(currency.label) to an exact value")
            Button("Set", action: commit)
                .buttonStyle(.bordered).controlSize(.small).disabled(Int64(setText) == nil)

            Spacer(minLength: Theme.Spacing.sm)

            Button("Max") { model.maximize(currency) }
                .buttonStyle(.bordered).controlSize(.small).tint(Theme.Color.coral)
                .accessibilityLabel("Set \(currency.label) to maximum")
            Button("Reset") { model.reset(currency) }
                .buttonStyle(.bordered).controlSize(.small)
                .accessibilityLabel("Reset \(currency.label)")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func commit() {
        guard !setText.isEmpty else { return }
        model.applyText(currency, setText)
        setText = ""
    }
}

/// One compact bulk-action row: icon · title + description · button.
struct BulkActionRow: View {
    let title: String
    let systemImage: String
    let description: String
    let accent: Color
    let buttonTitle: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage).foregroundStyle(accent).frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).foregroundStyle(Theme.Color.textPrimary)
                Text(description).font(.caption).foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer(minLength: Theme.Spacing.md)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered).controlSize(.small).tint(accent)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

/// One inventory item row: name · id · current count · inline "set".
struct InventoryItemRow: View {
    let model: SaveEditorModel
    let row: SaveEditorModel.InventoryRow
    @State private var setText = ""

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).foregroundStyle(Theme.Color.textPrimary)
                Text(verbatim: "#\(row.id)").font(.caption.monospaced()).foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer(minLength: Theme.Spacing.md)
            Text("\(row.count)")
                .monospacedDigit().foregroundStyle(Theme.Color.textSecondary)
                .frame(minWidth: 48, alignment: .trailing)
            TextField("set", text: $setText)
                .textFieldStyle(.roundedBorder).monospacedDigit().frame(width: 68)
                .onSubmit(apply)
                .accessibilityLabel("Set \(row.name) count")
            Button("Set", action: apply)
                .buttonStyle(.bordered).controlSize(.small).disabled(Int(setText) == nil)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private func apply() {
        guard let c = Int(setText), c >= 0 else { return }
        model.addInventoryItem(itemID: row.id, count: c)
        setText = ""
    }
}
