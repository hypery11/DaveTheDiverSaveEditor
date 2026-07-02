# Competitor Gap Analysis — 2026-07-03

Method: 4 parallel web sweeps (save editors / trainers / Cheat Engine tables / Nexus mods),
findings cross-checked against a decoded real save (`LocalFixtures/real_sample_GD.sav`).

## Landscape

| Tool | Kind | Persistent-value coverage |
|---|---|---|
| DaveSaveEd (upstream, Windows) | save editor | Gold/Bei/Flame/Follower + own/all ingredients — **we are a superset already** |
| nintendosaves.com (Switch, manual service) | save edit service | all fish, all amulets, all mutations, Kaiju Codex 100%, Ecowatcher 100%, all missions (full-star), Bancho hidden menus, all 3★ Ocean-Card weapons, staff maxed |
| Save Wizard (PS4) | save editor | currencies, follower, **Momo likability 999**, **Dave level**, iDiver upgrades, story positioning |
| WeMod / MrAntiFun (33 cheats) | trainer | persistent: set gold/bei/flame/Doni, item set-amount, no level limit, Max Appeal/Cooking/Procure/Serving; rest runtime |
| FLiNG / PLITCH / Cheat Happens / GreenHouse | trainer | persistent: currencies, ingredient amounts, weight capacity, [Jungle] NPC friendship; rest runtime |
| FearLess CE tables (ColonelRVH) | ce-table | gold lock, ingredient/ammo increase-on-use, harpoon/gun pointer edits; rest runtime |
| Nexus mods (BepInEx): DaveDiverExpansion, Harpoon Tip Manager, max-star fishes, FishMultiplier… | game mods | runtime QoL (auto-pickup, minimap, casino bets, charm slots); no unlock-all-recipes / encyclopedia mod exists |

## Gaps — classified

### A. Save-editable NOW (fields verified in our real-save dump; no data pipeline needed)
| Feature | Offered by | Evidence in save | Value/Effort |
|---|---|---|---|
| **Unlock/complete all weapons** | nintendosaves (3★ Ocean-Card), CE gun tables | `GunCraft` has **all 46 crafts already present** (`gunCraftState` 1=29, 2=17; `developedCount`) — flip states on existing entries | high / low |
| **Max all hired staff** | nintendosaves, WeMod (Appeal/Cooking/Procure/Serving) | `Staff[guid].level` exists per hire (level 1 seen) | high / low |
| **All caught fish → best grade** | max-star-fishes mod (runtime); service "all fish" | `CaughtFish[id].grade` 1–5 distribution seen; raise existing entries to 5 | med / low |
| **Story/chapter positioning** | Save Wizard | `Chapter.currentChapter` (=8 seen) | low / low — **soft-lock risk, keep read-only or gated** |

### B. Save-editable, needs a data pipeline (master ID lists → reference.sqlite)
| Feature | Offered by | Blocker |
|---|---|---|
| All fish **collected** (encyclopedia) | nintendosaves | need master fish-ID list (save has only caught 202) |
| All recipes / Bancho hidden menus | nintendosaves | `UnlockRecipe` holds only unlocked 221; need master recipe list |
| All amulets(charms)/mutations, Kaiju Codex, Ecowatcher | nintendosaves | need ID lists + flag-location research |
| All missions full-star | nintendosaves | `Mission` (261) exists but **story-flag risk**; research first |
| Momo likability / relationships; Dave level; weight capacity; iDiver upgrades; Jungle Doni/friendship | Save Wizard, FLiNG | field locations not yet identified in our dump (`Contacts` is just notification lists); needs targeted RE |

### C. Runtime-only — trainer territory, explicitly OUT OF SCOPE for a save editor
God mode / infinite oxygen / stamina / ammo / no-reload / one-hit-kill / damage multipliers /
no-weight (current) / swim & game speed / freeze fish / instant cooking / customer patience /
time controls / speedhack. These live in RAM only; every trainer has them, no save field exists.
**Do not chase.**

### D. Game-mod territory (BepInEx runtime behavior, not save data)
Auto-pickup, minimap HUD, fish population multipliers, extra charm slots, FPS unlock,
casino bet tiers, auto seahorse race. Out of scope.

## Recommendation (priority order)
1. **Unlock all weapons (GunCraft)** — all entries already in the save; biggest wow-per-effort. ✅
2. **Max all staff levels** — same pattern as our other bulk ops. ✅
3. **All caught fish → grade 5** — trivial; pairs with existing aberration-safe rules. ✅
4. The **data pipeline** (master fish/recipe IDs) unlocks the B-tier headliners (encyclopedia,
   recipes) — do once, reuse for everything.
5. Keep C entirely out; document that stance so scope stays clean.

## Resolution — 2026-07-03

Shipped (fields verified against the real save; standalone ints, no coupled data):
- **Max Staff Levels** → 20 (`Staff.<guid>.level`; cap 20 confirmed — 16/22 already there).
- **Max Caught-Fish Grade** → 5 (`CaughtFish.<id>.grade`; top grade observed). Does NOT add uncaught fish.
- Both wired into per-row buttons + "Max Everything" + bulk undo; engine + model tests added.

Held (would repeat the trust/fake "write-unverified-value" mistake):
- **GunCraft (weapon unlock/upgrade)** — `gunCraftState` / `developedCount` / `UIState` are interrelated in ways not clear from data alone (state 1 & 2 both show varied developedCount); needs in-game verification before writing.
- **CookingStudy (recipe upgrade level)** — `studyLevel` is coupled to a derived `finalStudyTasteValue`; writing level without the taste formula risks an inconsistent recipe.

Out of scope (confirmed, not a save-editor capability):
- **C-tier runtime cheats** (god mode / infinite oxygen / one-hit-kill / speed / freeze time). These are RAM-only per-frame values with NO save field. Reaching them requires a separate runtime trainer that attaches to the live process — on macOS that means defeating SIP + code-signing/entitlements against a Unity IL2CPP target, a fundamentally different (and fragile) program, not this editor. The persistent *equivalents* a save can offer are weapon/gear upgrade tiers and capacities (see B-tier / Held).
