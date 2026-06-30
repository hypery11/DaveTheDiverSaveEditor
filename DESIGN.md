# Design System — Dave The Diver Save Editor

> Native macOS (SwiftUI, arm64). This is the source of truth for every visual/UI
> decision. Values are expressed as SwiftUI idioms (SF system fonts, SF Symbols,
> points, semantic colors) — **no web fonts, no CSS**. Read this before touching any view.

## Product Context
- **What this is:** a native macOS save editor for the game *Dave the Diver*.
- **Who it's for:** players who want to tweak their own save (currencies, materials, seeds…).
- **Space:** game save-editor utility; peers are cross-platform Electron/WPF editors that look generic.
- **Project type:** single-window desktop utility (NavigationSplitView).

## Aesthetic Direction
- **Direction:** Cozy-native — warm, rounded, calm; echoes the game's sushi/diving mood while staying a first-class Mac citizen.
- **Decoration level:** intentional — soft card elevation, a faint warm ground, per-category accent colors. No heavy texture or gradients.
- **Mood:** "a cozy control panel." Friendly and tactile, never childish; reads as a polished Mac tool.
- **Memorable thing:** the big rounded number that springs when you tap ±.

## Typography (SF system fonts only)
- **Value display (the big number):** `.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit()` — SF Pro Rounded is the "cozy" signal; tabular digits stop width jitter while incrementing.
- **Card / section title:** `.system(.headline, design: .rounded)`.
- **Body / labels:** `.system(.body)` / `.system(.subheadline)` (default SF Pro).
- **Status / caption:** `.system(.caption)`, `.secondary`.
- **IDs / raw values (Advanced):** `.system(.body, design: .monospaced)`.
- **Dynamic Type:** use text styles where practical; the value display may use a fixed size but must stay legible. Never bundle a font.

## Color
Express as Asset-Catalog colors with light/dark variants (or `Color(light:dark:)` helper). Approach: **balanced** — warm neutrals + ocean base + a coral accent, semantic colors for +/− and status.

| Token | Light | Dark | Use |
|---|---|---|---|
| `bg` | `#FBF6EC` | `#14181B` | window background (warm cream / deep ink) |
| `surface` | `#FFFFFF` | `#1E2429` | card fill |
| `surface2` | `#F3ECDD` | `#262D33` | sidebar / inset |
| `separator` | `#E7DECB` | `#323A41` | hairlines |
| `textPrimary` | `#1F2A2E` | `#F0F4F3` | primary text |
| `textSecondary` | `#5C6B70` | `#9DB0B3` | secondary text |
| `ocean` (brand base) | `#1A8A94` | `#3FB6BE` | primary brand, links, focus |
| `coral` (accent) | `#FF7A59` | `#FF8C6E` | primary accent / Max button |
| `gold` | `#F2B705` | `#F7C72E` | economy accent |

**Per-category accent:** Economy = `gold`, Restaurant = `coral`, Farm = `leaf` `#5BA85A`, Inventory = `ocean` `#1A8A94` (light) / `#3FB6BE` (dark), Advanced = `slate` `#7A8B92`. (Each maps to a `Theme.Color` token of the same name.)

**Semantic / control:** success `#3FB27F`, warning `#F2B705`, error `#E5544B`, info `#2E9CCA`.
- **Delta buttons:** `+10/+100/+1000` tinted toward `success` green; `−10/−100/−1000` tinted toward `error` red (subtle `.tint`, not full fills).
- **Dark mode:** reduce accent saturation ~10–15%; prefer surface color + hairline border over heavy shadow.

## Spacing
- **Base unit:** 8pt. **Density:** comfortable.
- **Scale:** `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · 2xl 32`.
- **Card:** padding `16`, inter-card spacing `lg(16)`, content inset `xl(24)`.

## Layout
- **Approach:** `NavigationSplitView` — sidebar (categories) + detail (cards in a `ScrollView` + `VStack(spacing: 16)`).
- **Sidebar:** min `200`, ideal `220`; top = loaded-save chip (filename / "No save"), list of categories (SF Symbol + label + accent), bottom = Load / Save (Save shows an unsaved-changes dot).
- **Detail min width:** `500`. **Window min:** `760×560`.
- **Border radius (hierarchical):** control `8` · card `12` · pill/chip `full`.
- **Elevation:** light = `surface` + soft shadow (y `1`, blur `8`, ~8% black); dark = `surface` + `separator` hairline border (no shadow).

## Motion
- **Approach:** intentional.
- **Value change (± tap):** `.spring(response: 0.3, dampingFraction: 0.72)` — the number gives a small bounce/scale (~1.06) so editing feels tactile.
- **Selection / hover / status:** `.easeInOut(duration: 0.18)`.
- **Durations:** micro `80ms` · short `180ms` · medium `300ms`.

## Components (this app)
- **ValueCard** (Economy, one per editable value — Gold, Bei, Artisan's Flame, Follower, Research Point): SF Symbol + label (top), big rounded value display, a **DeltaStrip**, then an exact-entry field + `Max` + `Reset`. The value springs on any change.
- **DeltaStrip:** `−1000 −100 −10 ∣ +10 +100 +1000`. `.buttonStyle(.bordered)`, `.controlSize(.small)`, minus group `.tint(error)`, plus group `.tint(success)`. Each calls `model.adjust(_:by:)` (clamps ≥ 0 and through the engine's own max).
- **ActionCard** (Restaurant / Farm / Inventory bulk ops): SF Symbol + title + one-line description + primary button (accent-tinted) + a result status line. Used by Max Ingredients / Seeds / Craft Materials / etc.
- **AdvancedDetail:** the "add item by id:count" override (monospaced inputs).

## Per-category SF Symbols
Economy `dollarsign.circle.fill` · Restaurant `fork.knife` · Farm `leaf.fill` · Inventory `shippingbox.fill` · Advanced `wrench.and.screwdriver.fill`. Per-value: Gold `dollarsign.circle.fill`, Bei `fish.fill`, Artisan's Flame `flame.fill`, Follower `person.2.fill`, Research `flask.fill` (fallback `testtube.2`).

## SAFE vs RISK
- **SAFE (Mac-native expectations):** NavigationSplitView + system materials + semantic colors (free light/dark + accent following); SF system fonts (zero-bundle, accessible).
- **RISK (the product's face):** (1) SF Pro **Rounded** for value numbers; (2) warm **coral + multi-accent** palette vs the usual monochrome blue; (3) **spring "pop"** on ± taps.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-07-01 | Initial design system | `/design-consultation`; aesthetic = cozy-native (user pick); layout (sidebar+cards) and ±10/100/1000 delta controls locked in prior brainstorming. |
