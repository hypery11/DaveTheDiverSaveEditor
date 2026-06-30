# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Use the **swiftui-specialist** skill while writing SwiftUI in every task, and run a **design-review** pass after the final task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain grouped `Form` with a cozy-native `NavigationSplitView` (sidebar of categories + detail cards) and add ±10/±100/±1000 controls to every editable value.

**Architecture:** A view-layer rebuild. The model gains exactly one method (`adjust(_:by:)`); the engine, codec, write flow, `SaveGuard`, and menu commands are untouched and reused. New views read design tokens from a single `Theme` type that mirrors `DESIGN.md`.

**Tech Stack:** SwiftUI (macOS, arm64), XcodeGen-generated app target `DaveTheDiverSaveEditor`, SwiftPM `DaveSaveCore`. Swift Testing for tests. `xcodegen generate` regenerates the project after files are added/removed.

## Global Constraints
- Platform: macOS arm64, SwiftUI. **SF system fonts only** — no web/bundled fonts.
- **All** colors/spacing/radius/fonts/motion come from `Theme` (which mirrors `DESIGN.md`). No inline magic hex/size in views.
- Preserve verbatim: the write flow (`ChangePreviewView` sheet, `model.write()`, `SaveGuard`, backups, alert), `SaveEditorCommands` (⌘O/⌘L/⌘S), and `model.requestWrite` observation.
- Engine/codec/`DaveSaveCore` untouched.
- Existing tests stay green: **40 app + 70 core**. Run `xcodebuild test` (app) and `swift test` (core).
- Commits: no "Co-Authored-By"; no mention of Claude/AI/LLM anywhere (commit author `Dave The Diver Save Editor <hypery11@gmail.com>`).
- After adding/removing files in `App/Sources`, run `cd App && xcodegen generate` before building.

## File Structure
**Create**
- `App/Sources/EditorCategory.swift` — the 5 sidebar categories (label, SF Symbol, accent).
- `App/Sources/Theme.swift` — design tokens from `DESIGN.md` (colors light/dark, spacing, radius, fonts, motion) + `Color(hex:)` / `Color(light:dark:)` helpers.
- `App/Sources/Views/DeltaStrip.swift` — the ±10/±100/±1000 button row.
- `App/Sources/Views/ValueCard.swift` — one editable value (icon, big value, DeltaStrip, exact field, Max, Reset).
- `App/Sources/Views/ActionCard.swift` — a bulk-action card (icon, title, desc, button, status).
- `App/Sources/Views/Detail/EconomyDetail.swift`, `RestaurantDetail.swift`, `FarmDetail.swift`, `InventoryDetail.swift`, `AdvancedDetail.swift`.
- `App/Sources/Views/EditorSidebar.swift` — save chip + category list + Load/Save.

**Modify**
- `App/Sources/SaveEditorModel.swift` — add `adjust(_:by:)`.
- `App/Sources/Views/ContentView.swift` — `Form` → `NavigationSplitView`.

**Remove** (folded into the new views): `App/Sources/Views/CurrencyRow.swift`, `App/Sources/Views/IngredientsSection.swift`, `App/Sources/Views/FileInfoSection.swift`.

**Tests:** `App/Tests/SaveEditorModelTests/AdjustTests.swift` (new), `App/Tests/SaveEditorModelTests/EditorCategoryTests.swift` (new).

---

### Task 1: Design tokens (`Theme`) + `EditorCategory`

**Files:**
- Create: `App/Sources/Theme.swift`, `App/Sources/EditorCategory.swift`
- Test: `App/Tests/SaveEditorModelTests/EditorCategoryTests.swift`

**Interfaces:**
- Produces: `enum EditorCategory: String, CaseIterable, Identifiable { case economy, restaurant, farm, inventory, advanced }` with `var label: String`, `var systemImage: String`, `var accent: Color`. `Theme` with `Theme.Spacing.{xs,sm,md,lg,xl,xxl}` (CGFloat), `Theme.Radius.{control,card}`, `Theme.Color.{bg,surface,surface2,separator,textPrimary,textSecondary,ocean,coral,gold,success,error,warning,info}` (Color), `Theme.valueFont` (Font), `Theme.cardTitleFont` (Font), `Theme.valueSpring` (Animation). `Color(hex:)` and `Color(light:dark:)` initializers.

- [ ] **Step 1: Write the failing test**

```swift
// App/Tests/SaveEditorModelTests/EditorCategoryTests.swift
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd App && xcodegen generate && xcodebuild test -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -destination 'platform=macOS,arch=arm64' -only-testing:DaveTheDiverSaveEditorTests/EditorCategoryTests`
Expected: FAIL (EditorCategory / Theme don't exist).

- [ ] **Step 3: Create `Theme.swift`**

```swift
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
                   static let lg: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32 }
    enum Radius { static let control: CGFloat = 8, card: CGFloat = 12 }

    enum Color {
        static let bg            = SwiftUI.Color(light: .init(hex: 0xFBF6EC), dark: .init(hex: 0x14181B))
        static let surface       = SwiftUI.Color(light: .init(hex: 0xFFFFFF), dark: .init(hex: 0x1E2429))
        static let surface2      = SwiftUI.Color(light: .init(hex: 0xF3ECDD), dark: .init(hex: 0x262D33))
        static let separator     = SwiftUI.Color(light: .init(hex: 0xE7DECB), dark: .init(hex: 0x323A41))
        static let textPrimary   = SwiftUI.Color(light: .init(hex: 0x1F2A2E), dark: .init(hex: 0xF0F4F3))
        static let textSecondary = SwiftUI.Color(light: .init(hex: 0x5C6B70), dark: .init(hex: 0x9DB0B3))
        static let ocean         = SwiftUI.Color(light: .init(hex: 0x0E5C63), dark: .init(hex: 0x3FB6BE))
        static let coral         = SwiftUI.Color(light: .init(hex: 0xFF7A59), dark: .init(hex: 0xFF8C6E))
        static let gold          = SwiftUI.Color(light: .init(hex: 0xF2B705), dark: .init(hex: 0xF7C72E))
        static let leaf          = SwiftUI.Color(hex: 0x5BA85A)
        static let slate         = SwiftUI.Color(hex: 0x7A8B92)
        static let success       = SwiftUI.Color(hex: 0x3FB27F)
        static let warning       = SwiftUI.Color(hex: 0xF2B705)
        static let error         = SwiftUI.Color(hex: 0xE5544B)
        static let info          = SwiftUI.Color(hex: 0x2E9CCA)
    }

    static let valueFont     = Font.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit()
    static let cardTitleFont = Font.system(.headline, design: .rounded)
    static let valueSpring    = Animation.spring(response: 0.3, dampingFraction: 0.72)
}
```

- [ ] **Step 4: Create `EditorCategory.swift`**

```swift
// App/Sources/EditorCategory.swift
import SwiftUI

/// The sidebar categories. Order here is the sidebar order.
enum EditorCategory: String, CaseIterable, Identifiable {
    case economy, restaurant, farm, inventory, advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .economy:    return "Economy"
        case .restaurant: return "Restaurant"
        case .farm:       return "Farm"
        case .inventory:  return "Inventory"
        case .advanced:   return "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .economy:    return "dollarsign.circle.fill"
        case .restaurant: return "fork.knife"
        case .farm:       return "leaf.fill"
        case .inventory:  return "shippingbox.fill"
        case .advanced:   return "wrench.and.screwdriver.fill"
        }
    }

    var accent: Color {
        switch self {
        case .economy:    return Theme.Color.gold
        case .restaurant: return Theme.Color.coral
        case .farm:       return Theme.Color.leaf
        case .inventory:  return Theme.Color.ocean
        case .advanced:   return Theme.Color.slate
        }
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: the Step-2 command.
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add App/Sources/Theme.swift App/Sources/EditorCategory.swift App/Tests/SaveEditorModelTests/EditorCategoryTests.swift
git commit -m "feat(app): design tokens (Theme) and EditorCategory from DESIGN.md"
```

---

### Task 2: Model `adjust(_:by:)`

**Files:**
- Modify: `App/Sources/SaveEditorModel.swift`
- Test: `App/Tests/SaveEditorModelTests/AdjustTests.swift`

**Interfaces:**
- Consumes: existing `SaveEditorModel.value(_:) -> Int64?` and private `apply(_:_:)`.
- Produces: `func adjust(_ currency: Currency, by delta: Int64)`.

- [ ] **Step 1: Write the failing test**

```swift
// App/Tests/SaveEditorModelTests/AdjustTests.swift
import Testing
import Foundation
import DaveSaveCore
@testable import DaveTheDiverSaveEditor

@MainActor
@Suite struct AdjustTests {
    private func loaded() -> SaveEditorModel {
        let m = SaveEditorModel()
        m.load(data: SaveCodec.encode(#"{"PlayerInfo":{"m_Gold":1000,"m_Bei":50,"m_ChefFlame":7},"SNSInfo":{"m_Follow_Count":7}}"#), sourceURL: nil)
        return m
    }
    @Test func addsAndSubtracts() {
        let m = loaded()
        m.adjust(.gold, by: 100);  #expect(m.value(.gold) == 1100)
        m.adjust(.gold, by: -10);  #expect(m.value(.gold) == 1090)
    }
    @Test func clampsAtZero() {
        let m = loaded()
        m.adjust(.followerCount, by: -100)   // 7 - 100 -> 0, never negative
        #expect(m.value(.followerCount) == 0)
    }
    @Test func respectsUpperClampOfSetter() {
        let m = loaded()
        m.adjust(.gold, by: 999_999_999)     // setter clamps gold at 999,999,999
        #expect(m.value(.gold) == 999_999_999)
    }
    @Test func adjustEnablesWrite() {
        let m = loaded()
        m.adjust(.gold, by: 10)
        #expect(m.hasChanges)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd App && xcodegen generate && xcodebuild test -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -destination 'platform=macOS,arch=arm64' -only-testing:DaveTheDiverSaveEditorTests/AdjustTests`
Expected: FAIL ("value of type 'SaveEditorModel' has no member 'adjust'").

- [ ] **Step 3: Implement `adjust` in `SaveEditorModel.swift`**

Add this method next to `maximize`/`reset` (the editing section):

```swift
    /// Add `delta` to a value, clamped at 0 (and re-clamped to the setter's upper
    /// bound). Routes through the same `apply` path as exact entry, so dirty-tracking
    /// and engine clamps are unchanged. Powers the ±10/±100/±1000 buttons.
    func adjust(_ currency: Currency, by delta: Int64) {
        guard let current = value(currency) else { return }
        let next = max(0, current &+ delta)   // overflow-safe; setter re-clamps the top
        apply(currency, next)
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: the Step-2 command. Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add App/Sources/SaveEditorModel.swift App/Tests/SaveEditorModelTests/AdjustTests.swift
git commit -m "feat(app): add SaveEditorModel.adjust(_:by:) for granular value steps"
```

---

### Task 3: `DeltaStrip` + `ValueCard`

**Files:**
- Create: `App/Sources/Views/DeltaStrip.swift`, `App/Sources/Views/ValueCard.swift`

**Interfaces:**
- Consumes: `SaveEditorModel` (`adjust`, `value`, `displayText`, `applyText`, `maximize`, `reset`), `Currency` (`label`, currency icon — see below), `Theme.*`.
- Produces: `struct DeltaStrip: View { let model; let currency }`, `struct ValueCard: View { let model; let currency; let accent: Color }`. A `Currency.systemImage` computed property (add to `Currency.swift`).

- [ ] **Step 1: Add `systemImage` to `Currency`** (in `App/Sources/Currency.swift`, after `label`)

```swift
    /// SF Symbol shown on the value card.
    var systemImage: String {
        switch self {
        case .gold:          return "dollarsign.circle.fill"
        case .bei:           return "fish.fill"
        case .artisansFlame: return "flame.fill"
        case .followerCount: return "person.2.fill"
        case .researchPoint: return "flask.fill"
        }
    }
```

- [ ] **Step 2: Create `DeltaStrip.swift`**

```swift
// App/Sources/Views/DeltaStrip.swift
import SwiftUI

/// −1000 −100 −10 | +10 +100 +1000 for one value. Minus tinted error, plus tinted success.
struct DeltaStrip: View {
    let model: SaveEditorModel
    let currency: Currency
    private let steps: [Int64] = [10, 100, 1000]

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(steps.reversed(), id: \.self) { s in
                button(-s, tint: Theme.Color.error)
            }
            Divider().frame(height: 18)
            ForEach(steps, id: \.self) { s in
                button(s, tint: Theme.Color.success)
            }
        }
    }

    private func button(_ delta: Int64, tint: Color) -> some View {
        Button(delta > 0 ? "+\(abs(delta))" : "−\(abs(delta))") {
            model.adjust(currency, by: delta)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(tint)
        .monospacedDigit()
    }
}
```

- [ ] **Step 3: Create `ValueCard.swift`**

```swift
// App/Sources/Views/ValueCard.swift
import SwiftUI

/// One editable value: icon + label, a big rounded value that springs on change,
/// the DeltaStrip, and an exact field + Max + Reset.
struct ValueCard: View {
    let model: SaveEditorModel
    let currency: Currency
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label(currency.label, systemImage: currency.systemImage)
                .font(Theme.cardTitleFont)
                .foregroundStyle(accent)

            Text(model.displayText(currency).isEmpty ? "—" : model.displayText(currency))
                .font(Theme.valueFont)
                .foregroundStyle(Theme.Color.textPrimary)
                .contentTransition(.numericText())
                .animation(Theme.valueSpring, value: model.value(currency))

            DeltaStrip(model: model, currency: currency)

            HStack(spacing: Theme.Spacing.sm) {
                TextField("Value", text: Binding(
                    get: { model.displayText(currency) },
                    set: { model.applyText(currency, $0) }))
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .frame(width: 150)
                Button("Max") { model.maximize(currency) }
                Button("Reset") { model.reset(currency) }
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.separator))
        .disabled(!model.isLoaded)
    }
}
```

- [ ] **Step 4: Verify it builds**

Run: `cd App && xcodegen generate && xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -configuration Debug -destination 'platform=macOS,arch=arm64'`
Expected: BUILD SUCCEEDED. (Views are thin; correctness of `adjust` is covered by Task 2.)

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Currency.swift App/Sources/Views/DeltaStrip.swift App/Sources/Views/ValueCard.swift
git commit -m "feat(app): ValueCard with ±10/100/1000 DeltaStrip for editable values"
```

---

### Task 4: `ActionCard`

**Files:**
- Create: `App/Sources/Views/ActionCard.swift`

**Interfaces:**
- Produces: `struct ActionCard: View { let title: String; let systemImage: String; let description: String; let accent: Color; let buttonTitle: String; let isEnabled: Bool; let action: () -> Void }`.

- [ ] **Step 1: Create `ActionCard.swift`**

```swift
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
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.separator))
        .disabled(!isEnabled)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd App && xcodegen generate && xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -configuration Debug -destination 'platform=macOS,arch=arm64'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Views/ActionCard.swift
git commit -m "feat(app): reusable ActionCard for bulk operations"
```

---

### Task 5: Detail views (Economy, Restaurant, Farm, Inventory, Advanced)

**Files:**
- Create: `App/Sources/Views/Detail/EconomyDetail.swift`, `RestaurantDetail.swift`, `FarmDetail.swift`, `InventoryDetail.swift`, `AdvancedDetail.swift`

**Interfaces:**
- Consumes: `ValueCard`, `ActionCard`, `SaveEditorModel`, `Currency.allCases`, `EditorCategory.accent`, the model's bulk methods (`maxOwnIngredients`, `maxAllIngredients`, `maxBranchIngredients`, `maxSeeds`, `maxInventoryItems`, `maxMermanInventory`, `maxCraftMaterials`, `addInventoryItem`), `model.ingredientStatus`.
- Produces: 5 `View` structs, each `init(model:)`. A shared `statusFooter` view appended where bulk ops report.

- [ ] **Step 1: Create `EconomyDetail.swift`**

```swift
// App/Sources/Views/Detail/EconomyDetail.swift
import SwiftUI

struct EconomyDetail: View {
    let model: SaveEditorModel
    var body: some View {
        ForEach(Currency.allCases) { c in
            ValueCard(model: model, currency: c, accent: EditorCategory.economy.accent)
        }
    }
}
```

- [ ] **Step 2: Create `RestaurantDetail.swift`**

```swift
// App/Sources/Views/Detail/RestaurantDetail.swift
import SwiftUI

struct RestaurantDetail: View {
    let model: SaveEditorModel
    private var accent: Color { EditorCategory.restaurant.accent }
    var body: some View {
        ActionCard(title: "Max Owned Ingredients", systemImage: "tray.full.fill",
                   description: "Fill every ingredient you already own (skips perishable aberration fish).",
                   accent: accent, buttonTitle: "Max Own") { model.maxOwnIngredients() }
        ActionCard(title: "Max All Ingredients", systemImage: "tray.2.fill",
                   description: "Fill and inject every DLC-owned ingredient.",
                   accent: accent, buttonTitle: "Max All") { model.maxAllIngredients() }
        ActionCard(title: "Max Branch Store", systemImage: "building.2.fill",
                   description: "Stock the second sushi restaurant's branch counts.",
                   accent: accent, buttonTitle: "Max Branch") { model.maxBranchIngredients() }
        StatusFooter(text: model.ingredientStatus)
    }
}
```

- [ ] **Step 3: Create `FarmDetail.swift`**

```swift
// App/Sources/Views/Detail/FarmDetail.swift
import SwiftUI

struct FarmDetail: View {
    let model: SaveEditorModel
    var body: some View {
        ActionCard(title: "Max Seeds", systemImage: "leaf.fill",
                   description: "Fill every owned seed / produce stack in the home farm.",
                   accent: EditorCategory.farm.accent, buttonTitle: "Max Seeds") { model.maxSeeds() }
        StatusFooter(text: model.ingredientStatus)
    }
}
```

- [ ] **Step 4: Create `InventoryDetail.swift`**

```swift
// App/Sources/Views/Detail/InventoryDetail.swift
import SwiftUI

struct InventoryDetail: View {
    let model: SaveEditorModel
    private var accent: Color { EditorCategory.inventory.accent }
    var body: some View {
        ActionCard(title: "Max Inventory Items", systemImage: "shippingbox.fill",
                   description: "Raise general materials / crafting parts.",
                   accent: accent, buttonTitle: "Max Items") { model.maxInventoryItems() }
        ActionCard(title: "Max Craft Materials", systemImage: "hammer.fill",
                   description: "Stock fish parts and DREDGE research parts/bones so weapon crafting is unblocked.",
                   accent: accent, buttonTitle: "Max Craft") { model.maxCraftMaterials() }
        ActionCard(title: "Max Merman Village", systemImage: "drop.fill",
                   description: "Fill the Sea People village inventory.",
                   accent: accent, buttonTitle: "Max Village") { model.maxMermanInventory() }
        StatusFooter(text: model.ingredientStatus)
    }
}
```

- [ ] **Step 5: Create `AdvancedDetail.swift`** (includes the shared `StatusFooter`)

```swift
// App/Sources/Views/Detail/AdvancedDetail.swift
import SwiftUI

/// Shared status line used by the bulk-action detail panes.
struct StatusFooter: View {
    let text: String
    var body: some View {
        if !text.isEmpty {
            Text(text).font(.callout).foregroundStyle(Theme.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Power-user override: add/set a specific InventoryItemSlot by id and count.
struct AdvancedDetail: View {
    let model: SaveEditorModel
    @State private var itemIDText = ""
    @State private var countText = ""
    private var id: Int? { Int(itemIDText).flatMap { $0 > 0 ? $0 : nil } }
    private var count: Int? { Int(countText).flatMap { $0 >= 0 ? $0 : nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Add Inventory Item", systemImage: "plus.square.on.square")
                .font(Theme.cardTitleFont).foregroundStyle(EditorCategory.advanced.accent)
            Text("Set or inject a specific item by id and count (power-user).")
                .font(.subheadline).foregroundStyle(Theme.Color.textSecondary)
            HStack(spacing: Theme.Spacing.sm) {
                TextField("Item ID", text: $itemIDText).frame(width: 130)
                TextField("Count", text: $countText).frame(width: 100)
                Button("Add Item") { if let id, let count { model.addInventoryItem(itemID: id, count: count) } }
                    .disabled(id == nil || count == nil)
            }
            .textFieldStyle(.roundedBorder).monospacedDigit()
            StatusFooter(text: model.ingredientStatus)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Color.separator))
        .disabled(!model.isLoaded)
    }
}
```

- [ ] **Step 6: Verify it builds**

Run: `cd App && xcodegen generate && xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -configuration Debug -destination 'platform=macOS,arch=arm64'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add App/Sources/Views/Detail/
git commit -m "feat(app): category detail panes (economy, restaurant, farm, inventory, advanced)"
```

---

### Task 6: `EditorSidebar`

**Files:**
- Create: `App/Sources/Views/EditorSidebar.swift`

**Interfaces:**
- Consumes: `SaveEditorModel` (`detected`, `currentFileURL`, `isLoaded`, `hasChanges`, `detectLatestSave`, `loadDetected`), `EditorCategory`, `Theme.*`. A binding `selection: EditorCategory?` and two closures `onLoad` / `onSave`.
- Produces: `struct EditorSidebar: View { @Binding var selection: EditorCategory?; let model; let onLoad; let onSave }`.

- [ ] **Step 1: Create `EditorSidebar.swift`**

```swift
// App/Sources/Views/EditorSidebar.swift
import SwiftUI

struct EditorSidebar: View {
    @Binding var selection: EditorCategory?
    let model: SaveEditorModel
    let onLoad: () -> Void
    let onSave: () -> Void

    private var saveName: String {
        model.currentFileURL?.lastPathComponent ?? model.detected?.fileURL.lastPathComponent ?? "No save loaded"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: model.isLoaded ? "doc.fill" : "doc")
                    .foregroundStyle(model.isLoaded ? Theme.Color.ocean : Theme.Color.textSecondary)
                Text(saveName).font(.subheadline).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(Theme.Color.textPrimary)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)

            List(EditorCategory.allCases, selection: $selection) { c in
                Label(c.label, systemImage: c.systemImage)
                    .foregroundStyle(c.accent)
                    .tag(c)
            }

            Divider()
            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onLoad) { Label("Load", systemImage: "folder") }
                Spacer()
                Button(action: onSave) {
                    Label("Save", systemImage: "square.and.arrow.down")
                    if model.hasChanges {
                        Circle().fill(Theme.Color.coral).frame(width: 7, height: 7)
                    }
                }
                .disabled(!model.isLoaded || !model.hasChanges)
            }
            .padding(Theme.Spacing.md)
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd App && xcodegen generate && xcodebuild build -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -configuration Debug -destination 'platform=macOS,arch=arm64'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add App/Sources/Views/EditorSidebar.swift
git commit -m "feat(app): EditorSidebar with save chip, category list, Load/Save"
```

---

### Task 7: `ContentView` → `NavigationSplitView`; remove old section views

**Files:**
- Modify: `App/Sources/Views/ContentView.swift`
- Remove: `App/Sources/Views/CurrencyRow.swift`, `App/Sources/Views/IngredientsSection.swift`, `App/Sources/Views/FileInfoSection.swift`

**Interfaces:**
- Consumes: `EditorSidebar`, the 5 detail views, `ChangePreviewView`, `FileDialogs`, `model`. Preserves `showingPreview`, the `requestWrite` `onChange`, the alert, and `loadSaveFile()`.

- [ ] **Step 1: Replace the body of `ContentView.swift`**

```swift
// App/Sources/Views/ContentView.swift
import SwiftUI

/// Root editor screen. NavigationSplitView: sidebar of categories + a scroll of
/// cards. Owns no save/file logic — only composes views and the write-flow chrome.
struct ContentView: View {
    @Bindable var model: SaveEditorModel
    @State private var selection: EditorCategory? = .economy
    @State private var showingPreview = false

    var body: some View {
        NavigationSplitView {
            EditorSidebar(selection: $selection, model: model,
                          onLoad: loadSaveFile,
                          onSave: { showingPreview = true })
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    switch selection ?? .economy {
                    case .economy:    EconomyDetail(model: model)
                    case .restaurant: RestaurantDetail(model: model)
                    case .farm:       FarmDetail(model: model)
                    case .inventory:  InventoryDetail(model: model)
                    case .advanced:   AdvancedDetail(model: model)
                    }
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.Color.bg)
            .navigationTitle((selection ?? .economy).label)
        }
        .frame(minWidth: 760, minHeight: 560)
        .sheet(isPresented: $showingPreview) { ChangePreviewView(model: model) }
        .onChange(of: model.requestWrite) { _, newValue in
            if newValue { showingPreview = true; model.requestWrite = false }
        }
        .alert(item: $model.alert) { appAlert in
            if let url = appAlert.revealURL {
                return Alert(title: Text(appAlert.title), message: Text(appAlert.message),
                             primaryButton: .default(Text("Reveal Backup in Finder")) { model.revealInFinder(url) },
                             secondaryButton: .default(Text("OK")))
            } else {
                return Alert(title: Text(appAlert.title), message: Text(appAlert.message),
                             dismissButton: .default(Text("OK")))
            }
        }
    }

    private func loadSaveFile() {
        if let url = FileDialogs.openSaveFile(startDirectory: model.detected?.directoryURL) {
            model.load(url: url)
        }
    }
}
```

- [ ] **Step 2: Remove the three obsolete view files**

```bash
git rm App/Sources/Views/CurrencyRow.swift App/Sources/Views/IngredientsSection.swift App/Sources/Views/FileInfoSection.swift
```

- [ ] **Step 3: Regenerate + full build + full test suite**

```bash
cd App && xcodegen generate
xcodebuild test -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -destination 'platform=macOS,arch=arm64'
cd .. && swift test
```
Expected: app **40 + 6 new** tests pass (no references to the removed views remain — if `ContentView` still names `CurrencySection`/`IngredientsSection`/`FileInfoSection`, that is a compile error to fix); core 70 pass.

- [ ] **Step 4: Launch once to eyeball it**

```bash
cd App && open "$(xcodebuild -project DaveTheDiverSaveEditor.xcodeproj -scheme DaveTheDiverSaveEditor -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2}')/DaveTheDiverSaveEditor.app"
```

- [ ] **Step 5: Commit**

```bash
git add App/Sources/Views/ContentView.swift
git commit -m "feat(app): NavigationSplitView shell; retire Form section views"
```

---

### Task 8: `design-review` pass

Not a TDD task. After Task 7 is merged, run the **design-review** skill against the built app + `DESIGN.md`. Fix any flagged visual issues (spacing, hierarchy, contrast, AI-slop, missing accent usage) in the relevant view file, rebuild, and re-run the app test suite to confirm green. Commit fixes as `style(app): design-review fixes`.

---

## Self-Review
- **Spec coverage:** NavigationSplitView shell (Task 7) ✓; sidebar + save chip + Load/Save (Task 6) ✓; ValueCard + ±controls (Tasks 2,3) ✓; ActionCards for Restaurant/Farm/Inventory (Tasks 4,5) ✓; Advanced add-item (Task 5) ✓; Theme tokens from DESIGN.md (Task 1) ✓; model `adjust` only logic added (Task 2) ✓; remove CurrencyRow/IngredientsSection/FileInfoSection (Task 7) ✓; preserve write flow / SaveGuard / commands (Task 7 keeps sheet+alert+requestWrite; commands file untouched) ✓; design-review (Task 8) ✓.
- **Placeholders:** none — every code step is complete.
- **Type consistency:** `model.adjust(_:by:)` (Task 2) is called by `DeltaStrip` (Task 3); `Currency.systemImage` defined in Task 3 used by `ValueCard`; `EditorCategory.accent`/`label`/`systemImage` (Task 1) used by sidebar+details; `StatusFooter` defined in Task 5 (AdvancedDetail.swift) used by the other detail panes in the same task; `Theme.*` (Task 1) used throughout. Bulk method names match `SaveEditorModel` (`maxOwnIngredients`, `maxAllIngredients`, `maxBranchIngredients`, `maxSeeds`, `maxInventoryItems`, `maxMermanInventory`, `maxCraftMaterials`, `addInventoryItem`).
