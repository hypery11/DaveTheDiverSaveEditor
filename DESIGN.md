# Design System — DiveSaveEd

> Native macOS (SwiftUI, arm64 + Intel). This is the source of truth for every visual/UI
> decision. Values are expressed as SwiftUI idioms (SF system fonts, SF Symbols, points,
> semantic colors) — **no web fonts, no CSS**. Read this before touching any view.
>
> `App/Sources/Theme.swift` is the machine-readable mirror of this file. If the two
> disagree, `Theme.swift` is what ships — fix this document.

## Product Context
- **What this is:** a native macOS save editor for the game *Dave the Diver*.
- **Who it's for:** players who want to tweak their own save (currencies, materials, seeds…).
- **Space:** save-editor utility; peers are cross-platform Electron/WPF editors that look generic.
- **Project type:** single-window desktop utility.

## Aesthetic Direction
- **Direction:** Cozy-native — warm, calm, and a first-class Mac citizen.
- **Decoration level:** restrained. A warm ground and per-category accent colours. No
  texture, no gradients, no card elevation.
- **Mood:** "a cozy control panel." Friendly, never childish; reads as a polished Mac tool.

## Layout — one table, no tabs

**The whole editor is a single scrolling table.** `ScrollView` + `LazyVStack(spacing: 0,
pinnedViews: [.sectionHeaders])`, sections separated by pinned headers and hairline
dividers. Content is capped at `920`pt and centred; window minimum `900×600`.

Sections in order: **Economy** (one row per currency) → **Restaurant** (bulk fills) →
**Inventory** (bulk fills, then a search field and one row per owned item) → **Advanced**
(add an item by name or ID).

This replaced a `NavigationSplitView` sidebar-plus-cards design, which was **rejected on
purpose** as wasteful of space for a list of ~16 controls. Don't reintroduce tabs, a
wizard, or a sidebar of categories.

The consequence to design around: with no tabs, **section headers and search are
navigation, not decoration.** That is why headers are larger than row labels, carry
`.isHeader` for VoiceOver's heading rotor, and are opaque rather than translucent.

## Typography (SF system fonts only)
- **Section title:** `.system(.title3, design: .rounded).weight(.semibold)`.
- **Row label / value:** `.body`; the value adds `.title3.weight(.semibold).monospacedDigit()`
  — tabular digits stop width jitter while incrementing, and it goes `.bold` when the row
  differs from the value the save was opened with.
- **Row description / IDs:** `denseCaption()`, not `.caption` directly. Han and Hangul
  carry several times the stroke count of Latin at the same size, so the modifier steps up
  to `.footnote` with extra line spacing for CJK locales.
- **Never bundle a font.** Note that `design: .rounded` has **no Han or Hangul coverage**,
  so in three of the four shipped locales it silently falls back to PingFang / Apple SD
  Gothic Neo. Hierarchy must therefore come from size and weight, never from the typeface.

## Color

Two rules, both load-bearing:

1. **Legibility-critical neutrals come from AppKit semantic colors** — `separator`,
   `textPrimary`, `textSecondary` map to `.separatorColor` / `.labelColor` /
   `.secondaryLabelColor`. Hex literals cannot respond to System Settings ▸ Accessibility ▸
   Display ▸ Increase Contrast, which made that setting inert in this app; the branded cream
   separator also measured 1.24:1 against the cream ground while being the only thing
   delineating rows.
2. **Brand hues stay hex, but a tinted control's *label* uses its `…Text` variant.** An
   accent that reads well as a fill is usually too light as 11–13pt text.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#FBF6EC` | `#14181B` | window background (warm cream / deep ink) |
| `surface2` | `#F3ECDD` | `#262D33` | section-header fill, inset strips |
| `separator` / `textPrimary` / `textSecondary` | *semantic* | *semantic* | hairlines, text |
| `ocean` | `#1A8A94` | `#3FB6BE` | Inventory accent, links, focus |
| `coral` | `#FF7A59` | `#FF8C6E` | Restaurant accent, Max, dirty dot |
| `gold` | `#F2B705` | `#EABF4A` | economy accent **as a fill only** |
| `goldGlyph` | `#B27A00` | `#EABF4A` | economy accent **as a small glyph** — the fill value is 1.67:1 on cream, under the 3:1 floor |
| `leaf` | `#5BA85A` | `#7EBF7D` | (available; no current call site) |
| `slate` | `#7A8B92` | `#A0B2B8` | Advanced accent |
| `success` / `error` | `#3FB27F` / `#E5544B` | same | delta-strip tints |
| `successText` / `errorText` | `#26744E` / `#C4362E` | `#5FD39E` / `#F08A82` | delta-strip labels |
| `coralText` / `oceanText` / `leafText` / `warningText` | `#B54425` / `#166F78` / `#3B763A` / `#9A6300` | accent-matched | labels on tinted fills |

**Per-category accent:** Economy = `goldGlyph`, Restaurant = `coral`, Inventory = `ocean`,
Advanced = `slate`. A bulk action has **no accent of its own** — it derives from its
section, so a row cannot disagree with the header above it.

**Colour is never the only channel.** The delta strip reads
`accessibilityDifferentiateWithoutColor` and outlines its subtract half when that is on.

## Spacing
- **Base unit:** 8pt. **Scale:** `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32`.
- **Row:** `.horizontal xl(24)`, `.vertical sm(8)`. Dividers inset `xl` on **both** sides.
- **`iconGutter` (20):** every row type reserves it, so the text axis never jumps sideways
  between sections — including item rows, which have no icon of their own.

## Motion
- **Value change:** `.spring(response: 0.3, dampingFraction: 0.72)` keyed on the value, with
  `.contentTransition(.numericText())` so digits roll. `nil` under Reduce Motion.
- Keep the animation keyed on **the value**, not on a separate flag toggled in `onChange` —
  that fires after the render which already committed the new string, so the transition has
  nothing to animate.

## Components
- **`SectionHeader`** — accent glyph in the icon gutter + title, opaque `surface2` fill with
  a bottom hairline, `.isHeader`.
- **`EconomyRow`** — glyph · label · value · `DeltaStrip` · exact-value field · `Max` ·
  `Reset`. `Reset` disables when the row is unedited, so it doubles as a per-row dirty tell.
  Grouped as one accessibility element with the value carrying `accessibilityValue`.
- **`DeltaStrip`** — `−1k −100 −10 ∣ +10 +100 +1k`, uniform 34pt chips so the strip's width
  doesn't depend on the locale's font. A subtract button **disables when it would clamp to
  0** rather than subtract — four of the seven currencies sit in the low hundreds in a real
  save, so `−1k` there is a wipe. `buttonRepeatBehavior(.enabled)` for press-and-hold.
- **`BulkActionRow`** — glyph · title + description · trailing button with a `minWidth: 100`
  floor, so nine stacked buttons share a left edge without a fixed width that a longer
  translation would clip.
- **`InventoryItemRow`** — dimmed box glyph · name · `#id` · count · exact-value field.
- **`CountInput`** — the one parser behind every exact-value field, shared by the commit
  *and* the button's enabled test so they cannot disagree. Accepts grouped digits, rejects
  negatives.

## Text fields and buttons
The exact-value placeholder is a **noun** ("Exact value"), never the verb on the button
beside it: `set` and `Set` differ only in case in English and are the *same word* in Korean
and Traditional Chinese, so the row rendered 설정 / 設定 twice. The commit button appears
only once the field parses, and is an icon (`return`), which also reclaims row width.

## Keyboard
`⌘O` open · `⌘L` load latest · `⌘S` review-and-save · `⌘Z` / `⇧⌘Z` undo/redo (Edit menu,
covering currency *and* bulk edits) · Return commits a field · Escape clears it.

## SAFE vs RISK
- **SAFE:** system materials and semantic colors; SF system fonts; standard toolbar, sheets
  and confirmation dialogs.
- **RISK (the product's face):** (1) warm cream ground instead of system window grey; (2)
  multi-accent palette rather than monochrome blue; (3) a six-button delta strip where the
  Mac idiom would be a stepper — kept because `±1000` is discoverable for a game-mod
  audience that will not guess a stepper can be shift-clicked.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-01 | Initial design system | `/design-consultation`; aesthetic = cozy-native (user pick); sidebar+cards layout and ±10/100/1000 delta controls from prior brainstorming. |
| 2026-07-02 | **Rejected sidebar + cards; adopted one scrolling table, no tabs** | Owner call: cards wasted space for ~16 controls. Headers and search become navigation as a result. |
| 2026-08-01 | Neutrals moved to AppKit semantic colors; added `…Text` accent variants and `goldGlyph` | Increase Contrast was inert; separator measured 1.24:1 and gold-as-glyph 1.67:1. |
| 2026-08-01 | Bulk actions lost their per-action accent | "Max Seeds" kept leaf-green from a Farm category that had been folded into Inventory. Deriving from `section` makes the drift impossible. |
| 2026-08-01 | Documented that `.rounded` is Latin-only | The typographic signature exists in one of four shipped locales; hierarchy must come from size and weight. |

## Permanently out of scope
Recorded so they stop resurfacing as ideas. All three require attaching to or injecting
into the running game, and there is no non-attaching version: **runtime cheats** (unlimited
oxygen, instant cook), **value freezing/locking**, and an **in-game overlay**. Also barred:
**any network use** — no accounts, sync, telemetry, update checks or shared preset library.
The app makes zero network requests, and that is a design guarantee, not an omission.
