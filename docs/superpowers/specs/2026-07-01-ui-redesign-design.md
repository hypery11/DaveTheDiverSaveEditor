# UI Redesign — cozy-native shell + granular value controls

*Date: 2026-07-01 · Visual system: see `DESIGN.md` (source of truth for all colors/fonts/spacing/motion/components).*

## Goal
Replace the plain grouped `Form` with a **cozy-native** `NavigationSplitView` (sidebar of categories + detail cards), and give every editable value **±10/±100/±1000** controls in addition to exact-entry / Max / Reset. Engine and save-format code are untouched; the SwiftUI view layer is rebuilt and the model gains one method.

## Architecture
- `ContentView` becomes a `NavigationSplitView`:
  - **Sidebar** (`EditorSidebar`): loaded-save chip at top, a `List` of `EditorCategory` (SF Symbol + label + accent, selection-bound), Load / Save (Save shows an unsaved dot) at the bottom.
  - **Detail**: a `ScrollView` + `VStack(spacing: 16)` of cards for the selected category.
- The write flow is **preserved exactly**: ⌘S / Save → `ChangePreviewView` sheet → `SaveGuard` → backup → write → alert. Menu commands (`SaveEditorCommands`, ⌘O/⌘L/⌘S) unchanged. `FileInfoSection` content moves into the sidebar chip.
- Selection state (`@State selectedCategory`) lives in the view, not the model.

## File structure
**New**
- `App/Sources/EditorCategory.swift` — `enum EditorCategory: CaseIterable { economy, restaurant, farm, inventory, advanced }` with `label`, `systemImage`, `accent: Color`.
- `App/Sources/Theme.swift` — design tokens from `DESIGN.md`: `Theme.Color` (semantic + per-category, `Color(light:dark:)` helper), `Theme.Spacing` (xs…2xl), `Theme.Radius`, font helpers (`.valueDisplay`, `.cardTitle`), motion constants (`valueSpring`).
- `App/Sources/Views/EditorSidebar.swift` — sidebar (save chip + category list + Load/Save).
- `App/Sources/Views/ValueCard.swift` — icon + label + big rounded value (springs on change) + `DeltaStrip` + exact field + Max + Reset. Driven by a `Currency`.
- `App/Sources/Views/DeltaStrip.swift` — `−1000 −100 −10 ∣ +10 +100 +1000`; minus `.tint(Theme.error)`, plus `.tint(Theme.success)`, `.controlSize(.small)`; each button → `model.adjust(currency, by: delta)`.
- `App/Sources/Views/ActionCard.swift` — icon + title + description + primary button + status line; reusable for bulk ops.
- `App/Sources/Views/Detail/EconomyDetail.swift` — `ForEach(Currency.allCases)` → `ValueCard`.
- `App/Sources/Views/Detail/RestaurantDetail.swift` — ActionCards: Max Own / Max All / Max Branch.
- `App/Sources/Views/Detail/FarmDetail.swift` — ActionCard: Max Seeds.
- `App/Sources/Views/Detail/InventoryDetail.swift` — ActionCards: Max Inventory / Max Merman / Max Craft Materials.
- `App/Sources/Views/Detail/AdvancedDetail.swift` — the add-item (id:count) override.

**Modified**
- `App/Sources/Views/ContentView.swift` — Form → NavigationSplitView; keep the sheet/alert/toolbar/`onChange(requestWrite)` chrome.
- `App/Sources/SaveEditorModel.swift` — add `adjust(_:by:)` (below). Everything else (value/applyText/maximize/reset/bulk ops/write/SaveGuard/hasChanges) unchanged.

**Removed (folded into the above)**
- `App/Sources/Views/CurrencyRow.swift` (→ `ValueCard`), `App/Sources/Views/IngredientsSection.swift` (→ Restaurant/Farm/Inventory/Advanced details), `App/Sources/Views/FileInfoSection.swift` (→ sidebar chip). Regenerate the Xcode project (`xcodegen generate`) after add/remove.

## Model change — the only logic added
```swift
/// Add `delta` to a value, clamped at 0 (and through the setter's own max).
/// Routes through the same apply path as exact entry, so dirty-tracking and
/// engine clamps are unchanged. Used by the ±10/±100/±1000 buttons.
func adjust(_ currency: Currency, by delta: Int64) {
    guard let current = value(currency) else { return }
    let next = max(0, current &+ delta)      // overflow-safe; setter re-clamps the upper bound
    apply(currency, next)
}
```
(`apply` and `value` already exist and are private/internal to the model.)

## Visual tokens
All concrete values (hex per light/dark, font sizes, spacing, radius, spring params, SF Symbols) come from `DESIGN.md`. `Theme.swift` is the single Swift expression of that table; views reference `Theme.*` only — no inline magic colors/sizes.

## Testing
- New model test: `adjust` adds/subtracts, clamps at 0 (e.g. follower 7 − 100 → 0), and respects the upper clamp (gold + huge → 999,999,999). Add to the App test target.
- Views stay thin (no logic) so the existing 40 app + 70 core tests must remain green. Run `xcodebuild test` + `swift test`.
- A `design-review` pass (the skill) audits the built UI against `DESIGN.md` and fixes visual issues.

## Out of scope
Engine/codec, the save fields themselves, new editable categories (fish encyclopedia etc. stay a future Advanced/Fish addition). No window-state persistence beyond defaults.

## Risks
View-layer rewrite is sizable, but the model is preserved (one added method) and the write/guard flow is reused verbatim. The `adjust` clamp and dirty-tracking reuse the proven `apply` path.
