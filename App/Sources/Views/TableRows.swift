// App/Sources/Views/TableRows.swift
import SwiftUI

/// Parsing for the inline "exact value" fields.
///
/// One helper drives *both* the button's enabled test and the commit, because they used to
/// disagree: the button lit up for `-5` and then silently did nothing, while a pasted
/// `3,000,000` — the exact grouped form the app renders one control to the left — left the
/// button greyed with no explanation.
enum CountInput {
    /// Accepts digits with or without the locale's grouping separators; rejects anything
    /// negative or non-numeric.
    static func parse(_ text: String) -> Int64? {
        var stripped = text.trimmingCharacters(in: .whitespaces)
        for separator in [Locale.current.groupingSeparator, ",", " ", "\u{00A0}"].compactMap({ $0 }) {
            stripped = stripped.replacingOccurrences(of: separator, with: "")
        }
        guard !stripped.isEmpty, stripped.allSatisfy(\.isNumber) else { return nil }
        return Int64(stripped)
    }
}

/// Section header for the single-table layout: accent icon + title, pinned on scroll.
struct SectionHeader: View {
    let title: String
    let systemImage: String
    let accent: Color

    /// Build from a category so the header reuses its localized label, icon and accent
    /// rather than restating them (a plain `String` title would not be localized at all,
    /// since `Text(String)` skips localization).
    init(category: EditorCategory) {
        self.title = category.label
        self.systemImage = category.systemImage
        self.accent = category.accent
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(accent)
                .frame(width: Theme.Spacing.iconGutter)   // land the title on the row label axis
            Text(title).font(Theme.sectionTitleFont).foregroundStyle(Theme.Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque, not `.regularMaterial`: the material is a cool system neutral that
        // measured fainter than the row divider it outranks, and being translucent it let
        // rows ghost through the pinned header while scrolling.
        .background(Theme.Color.surface2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Color.separator).frame(height: 1)
        }
        // With no tabs, headers are the only navigation — so they must reach VoiceOver's
        // heading rotor.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// One compact currency row: icon · name · value · ±strip · exact entry · Max · Reset.
struct EconomyRow: View {
    let model: SaveEditorModel
    let currency: Currency
    @State private var setText = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { EditorCategory.economy.accent }
    private var grouped: String {
        model.value(currency).map { $0.formatted(.number.grouping(.automatic)) } ?? "—"
    }
    /// True when this row differs from the value the save was opened with.
    private var isDirty: Bool {
        guard let now = model.value(currency), let then = model.loadedValue(currency) else { return false }
        return now != then
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: currency.systemImage)
                .foregroundStyle(accent)
                .frame(width: Theme.Spacing.iconGutter)
                .accessibilityHidden(true)                 // the value element carries the name

            Text(currency.label)
                .frame(width: 130, alignment: .leading)
                .foregroundStyle(Theme.Color.textPrimary)
                .help(currency.caption)
                .accessibilityHidden(true)

            Text(grouped)
                .font(.title3.weight(isDirty ? .bold : .semibold).monospacedDigit())
                .foregroundStyle(Theme.Color.textPrimary)
                .frame(width: 116, alignment: .trailing)
                .contentTransition(.numericText())
                // Keyed on the value, not on a separate flag. It used to be keyed on a
                // `bounce` @State toggled inside `onChange` — i.e. after the render that
                // already committed the new string — so `numericText` had nothing to
                // animate and a 300ms sleeping Task raced itself on every click.
                .animation(reduceMotion ? nil : Theme.valueSpring, value: model.value(currency))
                .accessibilityLabel(currency.label)
                .accessibilityValue(grouped)               // what VoiceOver re-speaks on change
                .accessibilityHint(currency.caption)
                .accessibilityAdjustableAction { direction in
                    model.adjust(currency, by: direction == .increment ? 10 : -10)
                }

            DeltaStrip(model: model, currency: currency)
                .layoutPriority(-1)                        // chips carry no text; compress first

            TextField(text: $setText) { Text("Value") }
                .textFieldStyle(.roundedBorder).monospacedDigit().frame(width: 68)
                .onSubmit(commit)
                .onExitCommand { setText = "" }            // Escape drops a half-typed number
                .accessibilityLabel("Set \(currency.label) to an exact value")

            // Appears only once the field holds a usable number. Previously a permanently
            // disabled button sat in all seven rows, and its label collided with the
            // field's placeholder — `set` and `Set` are one word in Korean and
            // Traditional Chinese, so the row read 설정 / 設定 twice.
            if CountInput.parse(setText) != nil {
                Button(action: commit) { Image(systemName: "return") }
                    .buttonStyle(.bordered).controlSize(.small)
                    .help("Set \(currency.label) to an exact value")
                    .accessibilityLabel("Set \(currency.label) to an exact value")
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button("Max") { model.maximize(currency) }
                .buttonStyle(.bordered).controlSize(.small).tint(Theme.Color.coral)
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("Set \(currency.label) to maximum")
            Button("Reset") { model.reset(currency) }
                .buttonStyle(.bordered).controlSize(.small)
                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                .disabled(!isDirty)                        // also a free per-row dirty tell
                .help("Back to \(model.loadedValue(currency)?.formatted() ?? "—") — the value this save was opened with")
                .accessibilityLabel("Reset \(currency.label)")
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        // Group ~14 flat siblings under one row so VoiceOver announces a row, not a
        // stream of unlabelled buttons.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(currency.label)
    }

    private func commit() {
        guard let value = CountInput.parse(setText) else { return }
        model.setExact(currency, value)
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
            Image(systemName: systemImage)
                .foregroundStyle(accent)
                .frame(width: Theme.Spacing.iconGutter)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).foregroundStyle(Theme.Color.textPrimary)
                Text(description)
                    .denseCaption()
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: 520, alignment: .leading)     // shorten the eye's trip to the button
            Spacer(minLength: Theme.Spacing.md)
            Button(action: action) {
                // A floor, not a fixed width: nine free-width buttons gave nine different
                // left edges, and the raggedness re-rolled with every translation.
                Text(buttonTitle).frame(minWidth: 100)
            }
            .buttonStyle(.bordered).controlSize(.small).tint(accent)
            .lineLimit(1)
            .disabled(!isEnabled)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .accessibilityHint(description)
    }
}

/// One inventory item row: name · id · current count · inline exact entry.
struct InventoryItemRow: View {
    let model: SaveEditorModel
    let row: SaveEditorModel.InventoryRow
    @State private var setText = ""

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Reserve the same leading gutter the other two row types use, so the text
            // axis doesn't jump sideways when scrolling from bulk rows into the item list.
            Image(systemName: "shippingbox")
                .foregroundStyle(Theme.Color.textSecondary.opacity(0.5))
                .frame(width: Theme.Spacing.iconGutter)
                .accessibilityHidden(true)
            Text(row.name).foregroundStyle(Theme.Color.textPrimary).lineLimit(1)
            Text(verbatim: "#\(row.id)")
                .denseCaption().monospaced()
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer(minLength: Theme.Spacing.md)
            // `Text("\(row.count)")` made "%lld" a real localization key and skipped the
            // locale's digit grouping while the currency values above it grouped.
            Text(row.count, format: .number)
                .monospacedDigit().foregroundStyle(Theme.Color.textSecondary)
                .frame(minWidth: 48, alignment: .trailing)
            TextField(text: $setText) { Text("Value") }
                .textFieldStyle(.roundedBorder).monospacedDigit().frame(width: 68)
                .onSubmit(apply)
                .onExitCommand { setText = "" }
                .accessibilityLabel("Set \(row.name) count")
            if CountInput.parse(setText) != nil {
                Button(action: apply) { Image(systemName: "return") }
                    .buttonStyle(.bordered).controlSize(.small)
                    .help("Set \(row.name) count")
                    .accessibilityLabel("Set \(row.name) count")
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.name)
    }

    private func apply() {
        guard let count = CountInput.parse(setText) else { return }
        model.addInventoryItem(itemID: row.id, count: Int(count))
        setText = ""
    }
}

extension View {
    /// A caption that stays legible in Han and Hangul. Those glyphs carry several times the
    /// stroke count of Latin at the same point size, so 11pt `.caption` — fine for
    /// English — turns to mud in three of the four shipped locales.
    func denseCaption() -> some View { modifier(DenseCaption()) }
}

private struct DenseCaption: ViewModifier {
    @Environment(\.locale) private var locale

    private var isCJK: Bool {
        guard let code = locale.language.script?.identifier else {
            return ["zh", "ko", "ja"].contains(locale.language.languageCode?.identifier ?? "")
        }
        return ["Hans", "Hant", "Kore", "Jpan"].contains(code)
    }

    func body(content: Content) -> some View {
        if isCJK {
            content.font(.footnote).lineSpacing(2)
        } else {
            content.font(.caption)
        }
    }
}
