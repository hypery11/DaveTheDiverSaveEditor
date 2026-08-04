// App/Sources/Views/SupportPromptView.swift
import SwiftUI

/// The donation ask, shown at launch and after every third save.
///
/// The copy is personal and asks plainly, but every sentence in it is true: the Jungle DLC
/// really is unbought, and the reference database really does contain zero Jungle items as a
/// result, so "I can't add data for content I don't own" is a statement of fact rather than a
/// hardship story. That matters beyond honesty — a concrete, checkable reason is also the
/// version that reads as credible rather than as a plea.
struct SupportPromptView: View {
    let kind: SupportPromptKind
    @Environment(\.dismiss) private var dismiss

    private var headline: String {
        switch kind {
        case .launch:
            return String(localized: "DiveSaveEd is free — I could really use your help")
        case .afterWrites(let n):
            return String(localized: "That's \(String(n)) saves you've edited with DiveSaveEd")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "heart.fill").foregroundStyle(Theme.Color.coral)
                Text(headline).font(.headline)
            }

            Text("I build and maintain this on my own, in my spare time, and give it away free — no ads, no paid version, nothing locked.")
                .foregroundStyle(Theme.Color.textPrimary)

            Text("I still haven't been able to afford the In the Jungle DLC, which is why the app can't fill Jungle items yet — I can't build data for content I don't own.")
                .foregroundStyle(Theme.Color.textPrimary)

            Text("If DiveSaveEd saved you hours of grinding, please consider chipping in. Donations are crypto only, and any amount at all helps.")
                .foregroundStyle(Theme.Color.textSecondary)

            HStack {
                Spacer()
                Button("Not now") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Support the project") {
                    NSWorkspace.shared.open(SupportLinks.support)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.Color.coral)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(width: 460)
        .background(Theme.Color.bg)
    }
}
