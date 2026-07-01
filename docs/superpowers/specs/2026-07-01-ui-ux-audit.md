# UI / UX Audit — 2026-07-01

Method: captured all 5 panes + empty-state + dark mode from the running app (the new autonomous snapshot loop), then a 4-lens expert audit (visual-UI, UX/interaction, macOS-HIG/accessibility, information-architecture) reading the screenshots + code + `DESIGN.md`, plus a manual pass. Findings below are deduplicated and prioritized; **★ = flagged by ≥2 lenses**.

## 🔴 Critical

1. **BUG — bulk-only edits can't be saved.** `ChangePreviewView.swift:72` disables "Write Save" on `pendingChanges().isEmpty` (currency-only diff). Max Seeds/Craft/Inventory/etc. set `bulkEdited` (so Save/⌘S enable + open the sheet), but the sheet shows "No changes to write" and greys out Write → the core feature is a dead end in the GUI. **Fix:** gate the button on `!model.hasChanges`; add a bulk-ops summary section (accumulate an `appliedBulkOps: [String]` in the model, render as rows) so the preview reflects what will actually be written.
2. **★ Sidebar selection = system blue with accent-colored text on top.** Coral/teal/green labels on the blue selected row are near-illegible (teal≈1.6:1); it also throws away the warm multi-accent identity the moment you click. Unselected labels are fully accent-tinted too (gold-on-cream ≈1.5:1, fails WCAG). **Fix:** color only the SF Symbol, keep text at `textPrimary`; `.listStyle(.sidebar)` + `.tint(Theme.Color.ocean)`.
3. **★ ValueCard titles are accent-on-white (gold ≈1.8:1, fails WCAG).** ActionCard already does it right (accent icon + primary title); ValueCard/AdvancedDetail don't. **Fix:** same icon/label split.
4. **★ The value is shown twice.** Big "3,074,847" stacked on an identical raw field "3074847" reads as a glitch and halves the focal hierarchy. **Fix:** make the big number itself the editable control (borderless TextField in `valueFont`, grouped when unfocused), drop the duplicate field.
5. **★ Empty state lies + detected save isn't one-click loadable.** Chip shows "GameSave_00_GD.sav" while the pane says "No save loaded"; the app *detected* the newest save but the only way to open it is the hidden ⌘L. **Fix:** chip shows "No save loaded" when `!isLoaded`; empty-state primary button = "Open detected save (…)" → `model.loadDetected()`, file picker demoted to secondary.
6. **VoiceOver unusable for editing.** 5 identical "Max"/"Reset"/"Value"/"+10" controls with no currency context (zero accessibility modifiers in the app). **Fix:** `.accessibilityLabel("Set \(currency.label) to maximum")` etc.; pass `currency` into DeltaStrip for "Add 100 to Gold".
7. **Bulk actions: weak feedback + no undo.** One shared status line at the bottom (invisible/non-locating), inconsistent counts (maxOwn reports none), and `bulkEdited` is a one-way latch — a mis-tapped "Max All" can only be undone by reloading, which silently discards currency edits too. **Fix:** per-card status + count + a "done" check; snapshot-before-bulk for an Undo.

## 🟠 Important

8. **★ Cards look flat in light mode.** DESIGN.md wants light = soft shadow, dark = border; code does border-in-both, no shadow. **Fix:** `@Environment(\.colorScheme)`-gated `cardSurface()` modifier (shared across the 3 card files).
9. **Cards stretch full width → marooned buttons, sparse panes.** **Fix:** constrain the detail column to `maxWidth ≈ 640` centered.
10. **Exact field edits per-keystroke, can't be cleared, rejects silently.** Deleting all digits repopulates; paste/over-clamp give no feedback. **Fix:** local `@State` + commit on `.onSubmit`/blur + validation (red border + "Clamped to 999,999,999").
11. **★ Advanced needs raw numeric item IDs, no name search** — yet the bundled `reference.sqlite` has every item's name/icon. **Fix:** searchable item picker from `ReferenceDB`; echo the resolved name in status.
12. **Loading a save while dirty discards everything, no warning.** **Fix:** confirmation dialog when `model.hasChanges`.
13. **The signature "pop" ignores Reduce Motion.** **Fix:** gate `scaleEffect`/`animation` on `@Environment(\.accessibilityReduceMotion)`.
14. **Delta button labels fail small-text contrast** (green ≈2.4:1) — but +/− is color-blind-safe (glyphs). **Fix:** darker `successText`/`errorText` tokens for the glyph, keep the subtle fill.
15. **No window toolbar; title is the category, not the file.** Load/Save only in the sidebar footer (web-ish). **Fix:** add a `.toolbar` Open/Save; `.navigationDocument(url)`/subtitle for the filename + edited indicator.
16. **★ Category IA is fragmented** — Restaurant/Farm/Inventory are the same "max a container" pattern in 3 near-empty panes (Farm = 1 card). **Fix:** collapse to a "Bulk Fill" pane with sub-sections (5→4 or fewer tabs).
17. **★ Bulk-only; no per-item browse.** Can't see or set an individual material's current count. **Fix:** a `Table` of inventory slots (name+icon+count via ReferenceDB) with inline edit → `setInventoryItem`.
18. **Aberration-skip note inconsistent** (only Max Own says it; Max All/Branch also skip). **Fix:** consistent note.
19. **"Bei" has a fish icon + no explanation; Follower Count is a progression stat framed as currency.** **Fix:** truer glyph + one-line captions ("Sea People currency", "weapon-upgrade currency"); consider a Progression group.

## 🟡 Minor / polish
20. Delta `Divider()` renders as a stray hairline → use a short `Capsule` or asymmetric spacing.
21. Dark accents a touch hot (spec wants −10–15% saturation).
22. Save uses a **download** glyph (`square.and.arrow.down`) for a write; terminology drifts (Save/Write/Load) → settle on Open…/Save… + `arrow.up`.
23. Empty-state overlay keeps the category as the nav title.
24. Alert "OK" has no `role: .cancel` (Return/Escape ambiguous).
25. 34pt value font is fixed → won't grow with accessibility text size (`@ScaledMetric`).
26. Delta buttons small/tight (mis-tap = ×10 error) → `controlSize(.regular)` or more spacing.

## 🗺️ Roadmap (product gaps vs other DTD editors)
Unlock-all recipes, fish-encyclopedia completion, relationships, a read-mostly **Raw/JSON** view, and a one-click **"Max Everything"**. Reserve a "Progression" category + a "Raw" category so the IA grows coherently.

---
**Suggested order:** #1 (bug) → #2–#5 (visual legibility + load flow, all cheap) → #8–#10 (card polish + field editing) → #6/#13/#14 (accessibility) → #16–#17 (IA restructure, larger). Each fix can be verified via the snapshot loop before moving on.

---

## Resolution — 2026-07-02 (all findings addressed)

Every finding above was fixed, verified via the snapshot loop, and covered by the test suite (Core 73 + App 47 green). Commits: `9bcab46` (batch 1: #1 save bug, #2/#3 legibility, #4 value-once, #8 elevation, #9 width, #14/#20 delta) · `24424bc` (#5/#12/#15/#23/#24 load flow) · `b7aa5d2` (#16 Farm-fold, #18 notes, #19 Bei/Follower, #25 scaled font) · `eda7787` (#11/#17 per-item browse + name search) · `b29e083` (#7 bulk undo) · `9ec5daf` (#15 toolbar + Max Everything) · `5b9d751` (#21 dark gold).

- **Critical #1–#7:** all fixed. #7 delivered via `appliedBulkOps` in the preview + an **Undo last edit** button (mutateBulk snapshot stack) — the "per-card checkmark" was judged lower value than undo and left as the shared status line.
- **Important #8–#19:** all fixed. #15 toolbar added (Open / Max Everything / Save) and the sidebar footer retired.
- **Minor #20–#26:** #20/#21/#22/#23/#24/#25 fixed. #26 (delta hit-targets) left as-is — the buttons measure ~40×28pt in the captures, adequately tappable.
- **Roadmap:** added **Max Everything** (one-click, one undo step). Deferred (need game-data RE or have distinct UX): unlock-all-recipes, fish-encyclopedia completion GUI, relationships, a raw JSON view. `Progression` vs `Economy` split left as a future call (Follower Count now carries a "progression stat" caption instead).

Bonus fixes surfaced while implementing: item ids no longer render with thousand-separators (`Text(verbatim:)`); the value field can now be cleared/retyped (commit-on-submit); ⌘S/Save still routes through the preview + SaveGuard.

### Layout pivot — 2026-07-02 (single-table, no tabs)

After living with the sidebar + card panes, the cards read as too sparse (only ~2.5 currency cards fit on screen). Reworked to a **single scrolling table with pinned section headers** (Economy / Restaurant / Inventory / Advanced) and divider rows — no category tabs. Every currency is now one compact row (`name · value · ±strip · set · Max · Reset`), so all five are visible at once; bulk actions and the item browser are compact rows in the same scroll. Retired `EditorSidebar`, `ValueCard`, `ActionCard`, `ItemBrowser`, and the per-category Detail panes in favor of `TableRows.swift` (`SectionHeader` / `EconomyRow` / `BulkActionRow` / `InventoryItemRow`). DeltaStrip now uses compact `1k` labels so the strip never truncates in a row. Undo moved to the toolbar + a bottom status bar.
