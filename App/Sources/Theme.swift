// App/Sources/Theme.swift
import SwiftUI

extension Color {
    /// Build a Color from a 0xRRGGBB literal.
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
    /// Resolve to `light` or `dark` based on the current macOS appearance.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }
}

/// Swift mirror of DESIGN.md. Views reference Theme.* only — no inline magic values.
enum Theme {
    enum Spacing { static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 12
                   static let lg: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32
                   // Component-width tokens (not part of the density scale)
                   static let exactFieldWidth: CGFloat = 150
                   static let statusDotSize: CGFloat = 7
                   static let advancedIDFieldWidth: CGFloat = 130
                   static let advancedCountFieldWidth: CGFloat = 100 }
    enum Radius { static let control: CGFloat = 8, card: CGFloat = 12 }

    enum Color {
        static let bg            = SwiftUI.Color(light: .init(hex: 0xFBF6EC), dark: .init(hex: 0x14181B))
        static let surface       = SwiftUI.Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x1E2429))
        static let surface2      = SwiftUI.Color(light: .init(hex: 0xF3ECDD), dark: .init(hex: 0x262D33))
        static let separator     = SwiftUI.Color(light: .init(hex: 0xE7DECB), dark: .init(hex: 0x323A41))
        static let textPrimary   = SwiftUI.Color(light: .init(hex: 0x1F2A2E), dark: .init(hex: 0xF0F4F3))
        static let textSecondary = SwiftUI.Color(light: .init(hex: 0x5C6B70), dark: .init(hex: 0x9DB0B3))
        static let ocean         = SwiftUI.Color(light: .init(hex: 0x1A8A94), dark: .init(hex: 0x3FB6BE))
        static let coral         = SwiftUI.Color(light: .init(hex: 0xFF7A59), dark: .init(hex: 0xFF8C6E))
        static let gold          = SwiftUI.Color(light: .init(hex: 0xF2B705), dark: .init(hex: 0xF7C72E))
        static let leaf          = SwiftUI.Color(light: .init(hex: 0x5BA85A), dark: .init(hex: 0x7EBF7D))
        static let slate         = SwiftUI.Color(light: .init(hex: 0x7A8B92), dark: .init(hex: 0xA0B2B8))
        static let success       = SwiftUI.Color(hex: 0x3FB27F)
        static let warning       = SwiftUI.Color(hex: 0xF2B705)
        static let error         = SwiftUI.Color(hex: 0xE5544B)
        static let info          = SwiftUI.Color(hex: 0x2E9CCA)
        // Text-safe accent variants for small labels on tinted fills (WCAG on surface).
        static let successText   = SwiftUI.Color(light: .init(hex: 0x2E8B5E), dark: .init(hex: 0x5FD39E))
        static let errorText     = SwiftUI.Color(light: .init(hex: 0xC4362E), dark: .init(hex: 0xF08A82))
    }

    static let valueFont     = Font.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit()
    static let cardTitleFont = Font.system(.headline, design: .rounded)
    static let valueSpring    = Animation.spring(response: 0.3, dampingFraction: 0.72)
    /// Max reading measure for the detail card column (keeps cards from stretching).
    static let contentMaxWidth: CGFloat = 640
}

/// Shared card chrome (padding + surface + corner). Per DESIGN.md elevation: light gets
/// a soft shadow, dark gets a hairline border (no shadow). Used by every card.
struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay {
                if scheme == .dark {
                    RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.separator)
                }
            }
            .shadow(color: scheme == .dark ? .clear : .black.opacity(0.08), radius: 8, y: 1)
    }
}

extension View {
    func cardSurface() -> some View { modifier(CardSurface()) }
}
