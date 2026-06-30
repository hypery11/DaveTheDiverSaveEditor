# Expanded Editing & Real-Save Findings

*Date: 2026-07-01 · Status: built in `DaveSaveCore` + `dtdcli`, validated against a real save in-game; GUI integration pending.*

This document captures the editable fields and the **game-mechanic knowledge** discovered by exploring a real *Dave the Diver* save end-to-end (edit → load → verify in-game). These findings are load-bearing — several are non-obvious and cost real iterations to learn.

---

## 1. Expanded editable fields (built in the engine + CLI)

Beyond the v1 set (Gold/Bei/Artisan's Flame/Follower + ingredient max), the following are now implemented in `DaveSaveCore` and exposed via the `dtdcli` companion. **GUI buttons are the next work.**

| Feature | API | Save location | Notes |
|---|---|---|---|
| **Research Point** | `SaveDocument.researchPoint` / `setResearchPoint(_:)` | `PlayerInfo.m_researchPoint` | Spendable resource; clamped 0…999,999,999. Verified in-game. |
| **General inventory items** | `maxInventoryItems(using:)` | `InventoryItemSlot.<>.totalCount` | Materials/crafting items. Tiered via ref DB; unknown-but-stackable (count>1) → 999; skips `totalCount == -1` (unique/key items). |
| **Merman Village inventory** | `maxMermanInventory()` | `MermanVillInventory.<>.count` | Sea People village seeds/materials → 999. |
| **Branch (2nd store) ingredient stock** | `maxBranchIngredients(using:)` | `Ingredients.<>.branchCount` | See §2.2 — the critical `count` vs `branchCount` finding. |
| **Fish encyclopedia** | `addCaughtFish(fishID:grade:)` | `CaughtFish.<fishID>` = `{fishID,grade,isNew}` | Add/complete encyclopedia entries (the *collection*, distinct from the perishable fish *stock*). |
| **Direct ingredient count** | `setIngredientCount(id:count:)` | `Ingredients.<id>.count` | Low-level override (bypasses tier/DLC/aberration rules). |

The tier map (shared with v1) stays: `MaxCount ≥9999→6666, ≥999→666, ≥99→66, else skip`.

---

## 2. Game-mechanic findings (the expensive lessons)

### 2.1 Aberration fish (突變魚 / DLCType 1) are PERISHABLE — never bulk-max them
DREDGE "aberration" fish are `DLCType 1` ingredients (IDs incl. `1020201`–`1023081`). The game does **not** let them persist across nights: on load it discards any "leftover" aberration stock ("rotten aberration fish discarded"). Consequences:
- `maxOwnedIngredients` / `maxAllIngredients` / `maxBranchIngredients` **skip all `DLCType == 1` ingredients** (`IngredientOps.aberrationIDs`). Maxing them is pointless and triggers the discard, wiping the player's real catch.
- **But** the player CAN have the ones they actually caught: setting **only the freshly-caught aberration IDs** (the ones already at `count > 0`) to a high value via `setIngredientCount` **was accepted in-game** — the discard last time was triggered by inflating aberrations the player had **never caught** (count 0 → 6666). Rule: only ever touch aberration stock the player already owns this night.

### 2.2 Two stores: `count` (main) vs `branchCount` (branch)
There are **two sushi restaurants** (本店 + Maki's 分店). Each ingredient carries TWO stock counts in the same `Ingredients.<>` entry:
- `count` → main store
- `branchCount` → branch / second store
Maxing only `count` leaves the **branch material screen unfilled**. `maxBranchIngredients` raises `branchCount` to the same tier targets (skipping aberrations). Menu slots are split too: `SushiBarMenuData` `placeTagCode 0` = main, `1` = branch.

### 2.3 Steam Cloud silently reverts edits — disable it first
The #1 "my edit didn't work" cause: on launch Steam Cloud overwrites the locally-edited save with the old cloud copy. Always: quit game → Steam → Properties → General → uncheck "Keep game saves in the Steam Cloud" → edit → launch. (Documented in the README.)

### 2.4 Saving while the game runs is unsafe; the title screen flickers a lock
The game must be **fully quit** before writing — not just at the title screen, where it intermittently opens the save file to render the "Continue" preview (caught via `lsof`). Writes use `BackupStore.writeAtomically` (temp + atomic rename), so a transient OS/Spotlight touch is harmless, but an actively-running game will overwrite the edit on its next save.

---

## 3. Game-data extraction technique (how we got authoritative IDs)

The game ships an Addressables catalog at
`…/DaveTheDiver.app/Contents/Resources/Data/StreamingAssets/aa/catalog.json` (~25 MB JSON).
Asset paths embed **IDs + names**, e.g.
`…/Dredge/FIsh/2D/Dredge_Bony_Wreckfish/Prefabs/SA_2011216_Dredge_Bony_Wreckfish.prefab`
→ fishID `2011216` = "Dredge Bony Wreckfish" (a Dredge aberration).
Grepping `SA_<id>_<name>.prefab` yields the full fish roster (≈218 named fish, grouped by area: `Fish/A,B,C`, `Fish/FishMon`, `Fish/Seahorses`, `Fish/GlacialArea`, `00_Collabo/Dredge`). Cross-referencing with the save's `CaughtFish` gives exactly which fish the player is missing. **No bundle extraction needed** — the catalog paths are plain text. (Recipes are NOT exposed this way; they live in `DR_GameData_*.json` data sheets inside bundles.)

---

## 4. The `dtdcli` companion tool

A small headless CLI (`Sources/dtdcli`) over the same `DaveSaveCore` engine, used to apply/verify edits on real saves and as a power-user tool. `dtdcli batch <save> <ops…>` where ops include:
`gold=N bei=N flame=N follower=N research=N maxown maxall maxbranch maxinv maxmerman addfish=ID:GRADE seting=ID:COUNT`.
Every write makes a timestamped backup first.

---

## 5. Tier-1 status & what's next

- **Fish encyclopedia completion** — roster extracted (§3). The player is missing ≈36 entries, of which ~25 are real catchable fish (FishMon bosses, night variants, 1 aberration); the rest are non-encyclopedia (Seahorse-Race minigame entities, a "Dummy", id 0). `addCaughtFish` can complete the real ones; needs an in-game confirmation that injecting a `CaughtFish` entry registers in the Marinca collection (and whether `CaughtFishCountPerCategory` must be bumped — category 11 = aberrations).
- **GUI port (the immediate next work):** wire the §1 features into the SwiftUI app — a Research Point field and "Max Inventory", "Max Merman Village", "Max Branch Ingredients" buttons (and optionally a fish-completion action), all routed through `SaveEditorModel`.
- **Still unknown (need a real save dump to RE):** staff levels, weapons/Ocean-Card stars, recipes (data-sheet-bound), capacity stats. Use the §3 technique + a mid/late-game save.

---

*The aberration/branch findings above are the kind of thing only real-save + in-game testing surfaces. Keep that loop: edit → disable cloud → quit fully → load → verify.*
