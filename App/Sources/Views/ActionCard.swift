// App/Sources/Views/ActionCard.swift
import SwiftUI

/// A bulk action presented as a card: icon + title + one-line description + button.
struct ActionCard: View {
    let title: String
    let systemImage: String
    let description: String
    let accent: Color
    var buttonTitle: String = "Apply"
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(Theme.cardTitleFont).foregroundStyle(Theme.Color.textPrimary)
                Text(description).font(.subheadline).foregroundStyle(Theme.Color.textSecondary)
            }
            Spacer(minLength: Theme.Spacing.md)
            Button(buttonTitle, action: action).buttonStyle(.borderedProminent).tint(accent)
        }
        .cardSurface()
        .disabled(!isEnabled)
    }
}
