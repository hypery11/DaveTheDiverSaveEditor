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
///
/// Two rules earn their keep here:
///
/// * **Text, separators and other legibility-critical neutrals come from AppKit's semantic
///   colors, not hex literals.** Hard-coded hexes cannot respond to System Settings ▸
///   Accessibility ▸ Display ▸ Increase Contrast, so that setting was previously inert in
///   this app — and the branded cream separator measured 1.24:1 against the cream
///   background while being the *only* thing delineating rows.
/// * **Brand hues stay hex, but a tinted control's label uses its `…Text` variant.** A
///   saturated accent that looks right as a fill is usually too light as 11–13pt text: the
///   old `successText` measured 3.92:1 on the light ground (under the 4.5:1 floor) while
///   `errorText` passed at 4.98:1, so the two halves of one delta strip were not equally
///   legible.
enum Theme {
    enum Spacing { static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 12
                   static let lg: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32
                   /// Width of the leading icon gutter every row type aligns to.
                   static let iconGutter: CGFloat = 20
                   static let dirtyDotSize: CGFloat = 7 }

    enum Color {
        // Warm ground: the one piece of the cozy-native direction that survives in the
        // table layout, and safe as a background (it carries no text contrast burden).
        static let bg            = SwiftUI.Color(light: .init(hex: 0xFBF6EC), dark: .init(hex: 0x14181B))
        /// Section-header / inset fill. Warm sand, deliberately opaque so pinned headers
        /// don't let row content ghost through them.
        static let surface2      = SwiftUI.Color(light: .init(hex: 0xF3ECDD), dark: .init(hex: 0x262D33))

        // Semantic neutrals — track appearance AND Increase Contrast.
        static let separator     = SwiftUI.Color(nsColor: .separatorColor)
        static let textPrimary   = SwiftUI.Color(nsColor: .labelColor)
        static let textSecondary = SwiftUI.Color(nsColor: .secondaryLabelColor)

        // Brand hues. Used as fills, tints and (large) glyphs.
        static let ocean         = SwiftUI.Color(light: .init(hex: 0x1A8A94), dark: .init(hex: 0x3FB6BE))
        static let coral         = SwiftUI.Color(light: .init(hex: 0xFF7A59), dark: .init(hex: 0xFF8C6E))
        static let gold          = SwiftUI.Color(light: .init(hex: 0xF2B705), dark: .init(hex: 0xEABF4A))
        static let leaf          = SwiftUI.Color(light: .init(hex: 0x5BA85A), dark: .init(hex: 0x7EBF7D))
        static let slate         = SwiftUI.Color(light: .init(hex: 0x7A8B92), dark: .init(hex: 0xA0B2B8))
        static let success       = SwiftUI.Color(hex: 0x3FB27F)
        static let error         = SwiftUI.Color(hex: 0xE5544B)

        /// Gold as a *small glyph*. The fill value is 1.67:1 on the cream ground, well under
        /// the 3:1 floor for a meaningful graphical object, which made the Economy icon
        /// column read as one pale smear. Deeper amber still reads gold, not brown.
        static let goldGlyph     = SwiftUI.Color(light: .init(hex: 0xB27A00), dark: .init(hex: 0xEABF4A))

        // Text-safe accent variants: use these for a label drawn *on* a tinted fill.
        static let successText   = SwiftUI.Color(light: .init(hex: 0x26744E), dark: .init(hex: 0x5FD39E))
        static let errorText     = SwiftUI.Color(light: .init(hex: 0xC4362E), dark: .init(hex: 0xF08A82))
        static let coralText     = SwiftUI.Color(light: .init(hex: 0xB54425), dark: .init(hex: 0xFF8C6E))
        static let oceanText     = SwiftUI.Color(light: .init(hex: 0x166F78), dark: .init(hex: 0x3FB6BE))
        static let leafText      = SwiftUI.Color(light: .init(hex: 0x3B763A), dark: .init(hex: 0x7EBF7D))
        static let warningText   = SwiftUI.Color(light: .init(hex: 0x9A6300), dark: .init(hex: 0xF7C72E))
    }

    /// Section headers. Larger and heavier than a row label because in a layout with no
    /// tabs the headers are the only navigation — and because `.rounded` has no Han or
    /// Hangul coverage, so in three of four shipped locales the weight/size *is* the
    /// hierarchy.
    static let sectionTitleFont = Font.system(.title3, design: .rounded).weight(.semibold)
    static let cardTitleFont    = Font.system(.headline, design: .rounded)
    static let valueSpring      = Animation.spring(response: 0.3, dampingFraction: 0.72)
}
