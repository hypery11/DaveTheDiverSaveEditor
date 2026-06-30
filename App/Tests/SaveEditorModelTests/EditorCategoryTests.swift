import Testing
import SwiftUI
@testable import DaveTheDiverSaveEditor

@Suite struct EditorCategoryTests {
    @Test func fiveCategoriesEachWithLabelAndSymbol() {
        #expect(EditorCategory.allCases.count == 5)
        for c in EditorCategory.allCases {
            #expect(!c.label.isEmpty)
            #expect(!c.systemImage.isEmpty)
            #expect(c.id == c.rawValue)
        }
    }
    @Test func spacingScaleIsMonotonic() {
        #expect(Theme.Spacing.xs < Theme.Spacing.sm)
        #expect(Theme.Spacing.sm < Theme.Spacing.md)
        #expect(Theme.Spacing.md < Theme.Spacing.lg)
        #expect(Theme.Spacing.lg < Theme.Spacing.xl)
    }
}
