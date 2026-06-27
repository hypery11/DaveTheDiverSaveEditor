# Dave The Diver Save Editor — macOS (Apple Silicon) Design Spec

*Date: 2026-06-28 · Status: design, pending user review · Topic: native macOS save editor for the game **Dave the Diver**, an independent Swift reimplementation inspired by [FNGarvin/DaveSaveEd](https://github.com/FNGarvin/DaveSaveEd) (MIT).*

---

## 1. Goal & one-line pitch

Build **the first native macOS (Apple Silicon) save editor for *Dave the Diver*** — a free, open-source, 100% local SwiftUI app that lets Mac players precisely edit (or one-click max) Gold / Bei / Artisan's Flame / Follower Count and their ingredients, with a read-only viewer, automatic save detection, automatic backups, and change-preview-before-write. Published as an independent MIT project that credits the upstream Windows tool and seeks modest community sponsorship.

**Positioning:** *"The only native, free, instant, private, open-source save editor for Mac (Apple Silicon) Dave the Diver players — and the only one that edits Chinese/Korean saves without corrupting them."*

---

## 2. Confirmed decisions (locked with the user)

| # | Decision | Choice |
|---|---|---|
| D1 | Target platform | **macOS, arm64-only (Apple Silicon / M-series)**. Intel Macs out of scope. |
| D2 | UI | **Native SwiftUI** app. |
| D3 | Core language | **100% pure Swift** — no C/C++ shim. |
| D4 | Codec | **char-level (UTF-16 code unit) XOR**, mirroring the game's own algorithm — *more correct than upstream*. No `BYPASSED_HEX` hack, no regex. |
| D5 | JSON | Custom **lexeme-preserving `OrderedJSON`** (key order + big-int + no-reformat preserved). Foundation JSON is unusable. |
| D6 | Scope (v1) | **"Same field surface as upstream, better product."** Same editable fields (currencies + ingredients), but upgraded from blunt max-only to **view + precise edit + max preset + reset**, plus first-class safety (preview, persistent backup, warnings). Field-surface *expansion* is deferred to Tier 1. |
| D7 | Upstream relationship | **Independent project, clearly crediting** FNGarvin (MIT) and WhiteMinds (codec reverse-engineering). |
| D8 | Distribution (v1) | **Ship unsigned** (accept Gatekeeper friction, document the bypass; ad-hoc sign to avoid "is damaged"). Notarization is a later, fundable milestone. |
| D9 | Funding | **Platform deferred** pending region (Taiwan likely → Ko-fi / Open Collective / Liberapay may lead; GitHub Sponsors only if Stripe region allows). |
| D10 | Name | **"Dave The Diver Save Editor"** (repo: `dave-the-diver-save-editor`). |
| D11 | Windows | **Reserved, not built.** Pure-Swift core compiles on Windows later (needs vendored SQLite + its own CI). |

---

## 3. Competitive landscape & positioning (research summary)

**Verified: there is no native macOS Dave the Diver save editor anywhere as of 2026-06.** GitHub `language:Swift` + DtD editor = 0 results; the category leader and all three of its forks are Windows-only. **This app would be the first of its kind.**

| Competitor | Platform | Mac gap it leaves |
|---|---|---|
| [FNGarvin/DaveSaveEd](https://github.com/FNGarvin/DaveSaveEd) (9★) + 3 forks (Hew03, Anwar-ar, abaguai6689) | Windows-only | Mac players need Wine/CrossOver/Parallels |
| [WhiteMinds/dave-diver-expansion `save-codec`](https://github.com/WhiteMinds/dave-diver-expansion/tree/main/tools/save-codec) | Node.js (runs on Mac) | CLI only — **no editing, no maxing, no GUI** |
| [nintendosaves.com](https://nintendosaves.com/dave-the-diver/) | upload-and-pay service | **~$20**, ~1 hr, trust a stranger with your save |
| [paradoxie/saveeditor.top](https://github.com/paradoxie/saveeditor) (7★) | cross-platform web | **No DtD support** (structural threat if it ever adds it) |
| WeMod / FLiNG / MrAntiFun / Cheat Engine | Windows-only | None run on Apple Silicon |

**Demand (honest):** Real but **niche**. WeMod's DtD trainer shows 100K+ downloads (people want to cheat), but the *save-editor* sub-category ceiling is single-digit stars / ~tens of Nexus endorsements. **Crowdfund modestly — anchor expectations to tens-to-low-hundreds of supporters.** Conversion among Mac-only cheat-seekers should be high because it's the only native option.

**Differentiation moats (in priority order):**
1. **Correctness & safety — char-level (UTF-16) XOR.** This is sharper than "handles non-ASCII": upstream's bypass is **hard-coded to one exact farm-animal id**, so upstream is correct *only* for that one case and **silently corrupts** any save with a different/second non-ASCII string — and any **length-changing edit (Max-All injects entries!) on a CJK save** breaks it. Our codec has no special-casing → strictly safer, especially for the **CJK player base** (a realistic core audience for this niche). *Note honestly: on a pure-ASCII English save the codec unlocks no new fields — the moat is correctness/safety, not feature count.*
2. **Native Mac UX** — real SwiftUI app, auto-detects the macOS save dir, smart-selects the newest save. No Wine, no terminal.
3. **Precision + transparency** — exact-value editing (not just "max"), a read-only viewer, and change-preview-before-write — things trainers can't do and the $20 service charges for.
4. **Safety first** — automatic persistent backups + DLC-awareness, surfaced in the UI.

**Later opportunities (post-v1):** per-ingredient editing (Hew03 fork), expanded fields (fish encyclopedia, weapons, employees, recipes), and a **WASM/web port** of the codec to hedge against `saveeditor.top` and reach beyond Mac.

---

## 4. Functional design & feature scope (v1 = same scope, better product)

### 4.1 Philosophy — fix the "max hammer"

Upstream makes every action "set to MAX." That is blunt: all-or-nothing, no exact control, blind (you can't see current values or what will change), and "max" interacts badly with early-game scripting. A great *save editor* (vs a trainer or a paid service) wins on three axes trainers/services can't match: **precision** (exact values), **safety** (backup/restore/preview), and **transparency** (see what you have, see what will change). v1 keeps upstream's **known-safe field surface** but rebuilds the interaction around those three axes.

### 4.2 v1 feature set (all buildable from CODE-confirmed knowledge — no new reverse-engineering)

**Editable fields (same as upstream, known-safe):**
- Gold (`PlayerInfo.m_Gold`, clamp 999,999,999)
- Bei (`PlayerInfo.m_Bei`, clamp 999,999,999)
- Artisan's Flame (`PlayerInfo.m_ChefFlame`, clamp 999,999,999; "Max" button sends 999,999 per upstream)
- Follower Count (`SNSInfo.m_Follow_Count`, **unclamped** to match upstream; warn it may be recomputed early)
- Ingredients **Max-Own** (`Ingredients.<id>.count`, tiered targets ≥9999→6666, ≥999→666, ≥99→66)
- Ingredients **Max-All** (inject missing entries — full 9-key shape — DLC-filtered via `GameInfo.installedDLCs`)

**Interaction upgrades (the "better"):**
| Feature | Axis | Notes |
|---|---|---|
| 🔍 Read-only viewer | transparency | On load, show current values + file path / slot / mtime, so the user confirms they loaded the right, newest save |
| 🎯 Exact edit + "Max" preset + "Reset" | precision | Each currency: numeric entry (validated/clamped) **and** a Set-to-Max button **and** Reset-to-loaded-value. Ingredients keep Max-Own/Max-All presets (per-ingredient exact editing → Tier 1) |
| 👁 Change preview before write | safety | "Review changes": list `field: old → new` diff; confirm to commit |
| 💾 Automatic persistent backup | safety | Timestamped, in App Support (not temp), atomic write; **Reveal Backup in Finder** |
| ⚠️ Safety warnings | safety | Steam Cloud may overwrite edits; early-game scripting may override gold/followers; close the game first; DLC-aware injection |

### 4.3 v1 minimum safety bar (non-negotiable)

`automatic backup → atomic write → lossless OrderedJSON → load-confirmation viewer → confirm-before-write dialog → Steam-Cloud + early-scripting + DLC warnings.` Fully buildable today from confirmed knowledge.

### 4.4 The codec moat, stated precisely

Our char-level codec's unique value appears exactly where non-ASCII is present or an edit changes document length:
1. **`FarmAnimal[].Name` and any other non-ASCII string** — upstream's trigger is hard-coded to id `11090001`; any other case silently corrupts (0→11 U+FFFD measured). We handle all of it.
2. **Length-changing edits on CJK saves** — Max-All's injected entries (and any future deletes) shift byte offsets and break upstream's `BYPASSED_HEX`; our per-code-unit XOR is inherently safe. **So even v1 Max-All/Max-Own is strictly safer than upstream on CJK saves.**

### 4.5 Tiered roadmap for field expansion

- **Tier 1 (demand-driven, needs a real save to verify paths/safety):** per-ingredient exact editing (lowest risk — confirmed path, pure UX); a **raw JSON tree viewer + search** (highest-leverage — the enabling tool to discover unknown paths empirically); in-app restore-from-backup; in-session undo; lexeme-level diff/preview; then fish encyclopedia, missions full-star (`nowCounts` leaf known, container unknown — soft-lock risk), looting/Godzilla-figures/AchieveKeyToCount (keys known, interlocked — edit as a coordinated set), weapons / employees / recipes / amulets (unknown paths).
- **Tier 2 (advanced / risky, gate behind explicit warnings or defer):** story `Chapter` (soft-lock magnet); capacity stats O₂/weight/HP (likely recomputed from gear → edits silently revert); redemption codes / mutations (entitlement-validation risk); `installedDLCs` (**expose read-only only**, used as a safety filter); `Version` / `LastUpdateTime` (**never editable** — surface read-only with a "do not touch" note; `LastUpdateTime` is a >2^53 big-int that any whole-doc reserialize would corrupt).

### 4.6 Honest gaps

The shipped reference DB (`embedded_sql.h`: 563 Items, 305 Ingredients) is item/ingredient-centric only — it has **no** schema for weapons-as-owned, employees, missions, fish encyclopedia, recipes, or capacity stats. Pinning those paths **requires dumping a real mid/late-game save** (ideally one CJK + one English, with the Godzilla DLC) and grepping the decrypted JSON. This is why field expansion is Tier 1+, not v1.

---

## 5. The save format & codec (the crown-jewel knowledge)

This is the most subtle and most valuable part of the project. It must be implemented exactly and pinned by tests.

### 5.1 How the game actually encrypts saves

Reverse-engineered from the C# game (per WhiteMinds PORTING-NOTES, corroborated against upstream behavior):

**Game reads a save:**
1. Read file bytes, **UTF-8 decode** to a C# `string` (UTF-16 in memory) → the *encrypted string*.
2. **XOR each UTF-16 code unit** with `"GameData"` (8 chars), key index cycling **per code unit**: `plain[i] = enc[i] ^ "GameData"[i % 8]`.
3. The result is the plaintext **JSON**; parse it.

**Game writes a save:** the inverse — XOR the JSON string's code units with `"GameData"`, then **UTF-8 encode** to file bytes.

So **the on-disk `.sav` is the UTF-8 encoding of the per-code-unit-XOR'd JSON string.** The key is ASCII (all code units < 0x80). Scope: only `GameSave_<slot>_GD.sav` (and `m_*.sav`); `_PZ.sav`/`_UO.sav` are out of scope.

### 5.2 Why upstream (byte-level) is subtly wrong — and why we are not

Upstream C++/`encdec.py` XOR **raw UTF-8 bytes**. For ASCII, 1 byte = 1 code unit, so it works. But a CJK character (e.g. `白` U+767D) is **3 UTF-8 bytes** while the game treats it as **1 code unit** → after any multi-byte char the byte-vs-char key phase **desyncs** → corruption. Upstream never fixed the XOR; it detected one hard-coded `FarmAnimal` field and **bypassed** it (`BYPASSED_HEX::`). See §4.4 for why that bypass is correct only for one farm-animal id and breaks on length-changing edits.

**Our char-level implementation mirrors the game exactly** → correct for all content, **no `BYPASSED_HEX` hack, no `std::regex`**, and decode→(no edit)→encode is **byte-identical by construction**.

### 5.3 Swift implementation notes (and the one real subtlety)

Operate on **`[UInt16]` code-unit arrays**, not `Swift.String`, during XOR:

```
decode(fileData: Data) -> String (JSON):
    1. let encStr = String(decoding: fileData, as: UTF8.self)
    2. var units  = Array(encStr.utf16)
    3. for i in units.indices { units[i] ^= key16[i % 8] }   // key16 = "GameData".utf16
    4. return String(decoding: units, as: UTF16.self)

encode(json: String) -> Data:
    1. var units = Array(json.utf16)
    2. for i in units.indices { units[i] ^= key16[i % 8] }
    3. return Data(String(decoding: units, as: UTF16.self).utf8)
```

**Subtlety to test, not fear:** the *encrypted* intermediate code units could in theory contain lone surrogates (0xD800–0xDFFF), which strict Swift `String` rejects. In practice DtD saves are BMP-only (ASCII + CJK, no astral/emoji), XOR with an ASCII key keeps values out of the surrogate range, and the C# game would itself corrupt lone surrogates on its UTF-8 write — so by construction the real data never produces them. Written defensively over `[UInt16]` and validated by the round-trip + CJK-fixture tests (§8).

### 5.4 Why not `JSONSerialization` / `Codable`

Parse/serialize round-trips **corrupt** the save: **key order** must be preserved (Foundation reorders, esp. numeric-looking keys; upstream used `fifo_map`); **large integers** like `LastUpdateTime` (>2^53) lose precision / drift on reserialization. **Solution: `OrderedJSON`, a lexeme-preserving DOM** — every untouched token re-emits its verbatim source bytes; only edited leaves change; compact output matches the game's style; decode→parse→serialize with zero edits is byte-identical.

---

## 6. Architecture

```
┌───────────────────────────────────────────────────────────────┐
│  DaveTheDiverSaveEditor.app  (SwiftUI, @Observable, macOS 14+, │
│                               arm64)                            │
│        SaveEditorModel  ──drives──▶  DaveSaveCore               │
└───────────────────────────────────────────────────────────────┘
                              │  import DaveSaveCore  (100% Swift)
   ┌──────────────────────────┼─────────────────────────────────┐
   │ SaveCodec      OrderedJSON   SaveDocument   ReferenceDB      │
   │ (char-level    (lossless     (load/edit/    (SQLite via      │
   │  UTF-16 XOR)    DOM)          write API)     system          │
   │                                              libsqlite3)     │
   │ SaveLocator (macOS paths)   BackupStore (persistent, atomic) │
   └──────────────────────────────────────────────────────────────┘
```

**Monorepo, two products:**
- `DaveSaveCore` — pure-Swift SwiftPM package (all logic, fully unit-tested, no UI). Designed to also compile on Windows/Linux later.
- `DaveTheDiverSaveEditor` — the SwiftUI macOS app (thin; depends on `DaveSaveCore`).

### 6.1 `DaveSaveCore` components

| Component | Responsibility | Notes |
|---|---|---|
| `SaveCodec` | char-level UTF-16 XOR decode/encode | §5; `[UInt16]`; pure, deterministic, no I/O |
| `OrderedJSON` | lexeme-preserving JSON DOM | object = ordered `[(key,value)]`; scalars store verbatim lexeme; compact re-serialize |
| `SaveDocument` | load/edit/write API | getters/setters at known paths; currency clamp `999_999_999`; follower **unclamped**; exposes a "pending changes" diff for preview |
| `ReferenceDB` | ingredient/items reference data | SQLite read-only; ships `reference.sqlite` (default) + checked-in `reference.sql`; `import SQLite3` (Apple SDK) |
| `IngredientOps` | Max-Own / Max-All logic | tier map; DLC filter `{1:14252001,3:14252201,5:14252401}` vs `installedDLCs` |
| `SaveLocator` | find the newest macOS save | known roots + numeric sub-folders; newest `contentModificationDate` |
| `BackupStore` | timestamped pre-write backups + listing | persistent under App Support; atomic write; lists backups (for Tier-1 in-app restore) |

### 6.2 `SaveDocument` public API (sketch)

```swift
public struct SaveDocument {
    public static func load(_ data: Data) throws -> SaveDocument
    public func encoded() throws -> Data

    public var gold: Int64 { get }          ; public mutating func setGold(_ v: Int64)          // clamp
    public var bei: Int64 { get }           ; public mutating func setBei(_ v: Int64)           // clamp
    public var artisansFlame: Int64 { get } ; public mutating func setArtisansFlame(_ v: Int64) // clamp
    public var followerCount: Int64 { get } ; public mutating func setFollowerCount(_ v: Int64) // no clamp

    public mutating func maxOwnedIngredients(using ref: ReferenceDB)
    public mutating func maxAllIngredients(using ref: ReferenceDB)   // DLC-filtered, appends missing

    public func pendingChanges() -> [FieldChange]   // [(path, oldLexeme, newLexeme)] for preview
}
```

Editable paths: `PlayerInfo.m_Gold`, `PlayerInfo.m_Bei`, `PlayerInfo.m_ChefFlame`, `SNSInfo.m_Follow_Count`, `Ingredients.<id>.count`.

---

## 7. macOS save discovery, backup & write

**Save locations** (Mac Steam build is **not sandboxed** → real `~/Library`; use `FileManager.homeDirectoryForCurrentUser`):
- **Primary (VERIFIED on a real Apple Silicon install, 2026-06-28):** `~/Library/Application Support/com.nexon.dave/SteamSData/<numeric steam id>/` — note: **no "DAVE THE DIVER" subfolder**, and `SteamSData` (not `SData`).
- **Additional roots (from docs / other installs):** `~/Library/Application Support/nexon/DAVE THE DIVER/SteamSData/`, `…/nexon/DAVE THE DIVER/SData/`. Discovery enumerates all existing roots and picks the newest file, so extra roots are harmless.
- **Filenames (same as Windows):** autosave `GameSave*_GD.sav`, manual `m_*.sav`.

**Discovery (`SaveLocator.newestSave()`):** for each existing root, scan the root itself **plus** every immediate all-ASCII-digit subfolder; match `GameSave*_GD.sav` / `m_*.sav`; return the globally-newest file + its directory. (Xbox discovery dropped — no MS Store build on macOS.) Off-main; hop to `@MainActor` for the panel.

**Backups (`BackupStore`):** **persistent**, *not* temp (macOS prunes temp → silent loss):
```
~/Library/Application Support/<bundleID>/Backups/<stem>_yyyyMMdd_HHmmss.sav
```
`./backups` beside the save as fallback. Local-time timestamp (`en_US_POSIX`, `yyyyMMdd_HHmmss`). Retention: keep all (OQ-B).

**Write flow:** backup first (report path to UI) → preview diff → confirm → `SaveDocument.encoded()` → `Data.write(to:options:.atomic)`.

**Open UX:** `NSOpenPanel` pre-pointed at the discovered id-folder; a separate **"Load Latest Save"** button opens the detected file directly (the real auto-detect UX).

---

## 8. Testing strategy (load-bearing)

Tests are the safety net that replaces "reuse the proven C++ codec." Swift Testing.

1. **Codec byte round-trip:** for each real sample `.sav`, `encode(decode(x)) == x` byte-for-byte (no edits).
2. **CJK correctness:** a fixture with Chinese/Korean names (e.g. `白毛鸡`) round-trips with **zero** U+FFFD — and a save whose first farm animal is **not** id `11090001` (the case upstream silently corrupts) round-trips cleanly.
3. **Length-change safety:** Max-All on a CJK fixture (injects entries → changes length) re-encodes without corrupting the bypassed/non-ASCII regions.
4. **Cross-oracle:** decode output matches the [WhiteMinds Node `save-codec`](https://github.com/WhiteMinds/dave-diver-expansion/tree/main/tools/save-codec) on the same input.
5. **OrderedJSON no-op:** parse→serialize with no edits is byte-identical (guards whitespace, float format, 64-bit ints like `LastUpdateTime`, non-ASCII keys, numeric key order).
6. **Edit-only-changes:** setting Gold changes exactly the Gold lexeme and nothing else (drives the preview diff).
7. **ReferenceDB:** row counts (563 Items / 305 Ingredients), tier mapping, DLC filtering.

**Fixtures are synthetic / anonymized** — never commit a real user's save. Include at least one CJK fixture and one non-`11090001` farm-animal fixture.

---

## 9. Distribution (v1 unsigned → notarized later)

**v1 ships unsigned** (D8). On 2026 macOS the right-click→Open bypass is gone; users go **System Settings → Privacy & Security → "Open Anyway"** (auth, one-hour window) — documented with screenshots. Apple Silicon requires at least an **ad-hoc signature** to run; the build ad-hoc signs (`codesign -s -`) to avoid "is damaged."

**Build:** arm64-only `.app`; link OS `libsqlite3.dylib` (no bundling). Floor **macOS 14 Sonoma** (covers all M-series Macs; OQ-A).

**Notarization (later, fundable milestone):** Apple Developer Program ($99/yr) → Developer ID + Hardened Runtime → `notarytool submit --wait` → `stapler staple` → notarized DMG + Homebrew cask. The headline use of sponsorship money. App is **non-sandboxed** (save path not TCC-protected → no Full Disk Access prompt).

---

## 10. CI/CD (GitHub Actions, macOS runner)

| Job | Trigger | Secrets | Does |
|---|---|---|---|
| `test` | every push + PR (incl. forks) | No | `swift test` on `DaveSaveCore` (codec round-trip, CJK, length-change, OrderedJSON, ReferenceDB) |
| `build` | every push + PR | No | `xcodebuild` an unsigned ad-hoc arm64 `.app`; upload artifact |
| `release` | `v*` tag (later, once notarizing) | Yes | sign + notarize + staple → DMG + zip → `gh release create` |

Pin runner + Xcode + actions to SHAs. Forks never get secrets. The `release` signing steps are added when notarization lands.

---

## 11. Open-source hygiene, attribution & funding

**Attribution (we reimplement rather than copy code → credit concept + reference data + codec insight):**
- **LICENSE:** MIT, noting it is an independent reimplementation inspired by FNGarvin/DaveSaveEd.
- **NOTICE / README credits:** prominently credit **FNGarvin** (original tool, feature set, save-path knowledge, ingredient reference data if reused) and **WhiteMinds** (codec reverse-engineering). Link both. Restate **non-affiliation with Mintrocket / Nexon**.
- **CONTRIBUTING.md:** v1 = same-scope + correctness; upstream-first etiquette (offer platform-agnostic fixes back to FNGarvin); codec/edit changes require round-trip + CJK tests; **synthetic fixtures only**; **no "Co-Authored-By" / no AI mentions** (project policy).
- **Pre-launch courtesy:** heads-up to FNGarvin & WhiteMinds; point sponsors at thanking them too.

**Funding (D9 — platform deferred):** `.github/FUNDING.yml` finalized once region is known. If Taiwan: lead with **Ko-fi** (0% on tips, no approval, no supporter account) and/or **Open Collective / Liberapay**; GitHub Sponsors only if Stripe region allows. Tiers are honest "coffee money"; copy states the app is **free/MIT forever** and sponsorship buys **no features** — it funds the Apple Developer fee / notarization. Binary stays free.

---

## 12. Phased roadmap

**Phase 0 — Foundations**
- Establish the **independent repo** `dave-the-diver-save-editor` (upstream clone kept as local reference only; new project does **not** inherit upstream git history). This design doc = the new repo's first commit.
- LICENSE / NOTICE / README credits / CONTRIBUTING / topics / `.github/FUNDING.yml` (region-gated).
- Courtesy heads-up to FNGarvin & WhiteMinds.

**Phase 1 — `DaveSaveCore` (the load-bearing core)**
- `SaveCodec` (char-level UTF-16 XOR over `[UInt16]`), `OrderedJSON` lossless DOM, `SaveDocument` getters/setters + clamps + `pendingChanges()`, `ReferenceDB` + `IngredientOps`, `SaveLocator` + `BackupStore` + atomic write.
- Full test suite (§8) incl. CJK + non-`11090001` farm-animal + length-change + WhiteMinds cross-oracle. `test` CI green.

**Phase 2 — SwiftUI app (v1: same scope, better)**
- `@MainActor @Observable SaveEditorModel`; read-only viewer; per-currency exact entry + Max preset + Reset; ingredient Max-Own/Max-All with status feedback; change-preview-before-write; confirm dialog; persistent backup + Reveal-in-Finder; Steam-Cloud / early-scripting / DLC warnings; `NSOpenPanel` + empty-state "Load Latest Save"; ⌘O/⌘S; About box with attribution; `-log` → OSLog. `build` CI green (unsigned arm64 `.app`).

**Phase 3 — Release v1 (unsigned)**
- Ad-hoc-signed arm64 DMG/zip on GitHub Releases; README install + Gatekeeper-bypass guide; funding section. **Ship.**

**Later (Tier 1+ / milestones)**
- **Tier 1 functional:** per-ingredient exact editing; **raw JSON tree viewer + search** (enabling tool to RE unknown paths); in-app restore-from-backup; in-session undo; lexeme diff/preview; then fish encyclopedia / missions / looting+figures+achieve / weapons / employees / recipes (each needs a real-save dump to pin paths & verify safety).
- **Notarization milestone** (Apple Developer enrollment, signed+notarized DMG, Homebrew cask) — funded by sponsors.
- **Windows reachability** (vendor SQLite as a C target, `#if os(Windows)` paths, own CI; reuse `DaveSaveCore` from a Win frontend).
- **WASM/web port** of the codec to hedge `saveeditor.top` and reach beyond Mac.

---

## 13. Open questions to confirm (low-stakes; sensible defaults chosen)

- **OQ-A:** Deployment floor **macOS 14 Sonoma** (default) vs newer for newer SwiftUI APIs?
- **OQ-B:** Backup retention — **keep all** (default) vs prune to last N?
- **OQ-C:** Reference DB shipping — **prebuilt `reference.sqlite` + checked-in `reference.sql`** (default) vs exec into `:memory:`?
- **OQ-D:** Final **bundle identifier** (e.g. `com.<you>.davethediversaveeditor`) — needs your handle/domain.
- **OQ-E:** Confirm dropping Win32 quit-after-write (keep window open + success alert) — default yes.
- **OQ-F (resolved → confirm):** v1 currencies = **exact entry + Max preset + Reset** (not max-only). Confirmed by the "same scope, better" decision.
- **OQ-G:** Verify `SData` / `com.nexon.dave` fallback roots on a real install, or accept as best-effort fallbacks?
- **OQ-H (funding/region):** Your region (private), GitHub handle, funding platform lead — for `FUNDING.yml`, copyright line, bundle ID.
- **OQ-I:** Confirm **in-app restore-from-backup** and **in-session undo** are **Tier 1** (v1 covers safety via backup + Finder-reveal + reload), per the feature research.

---

## 14. Consolidated risks

| ID | Risk | Mitigation |
|---|---|---|
| R1 | char-level codec correctness rests on a single reverse-engineering source | Round-trip + CJK + non-`11090001` + length-change + WhiteMinds cross-oracle tests are the proof; pin before any release |
| R2 | XOR'd intermediate could (in theory) hold lone surrogates strict Swift `String` rejects | Operate on `[UInt16]`; BMP-only data avoids it; covered by tests |
| R3 | Accidental edit to a non-touched JSON token breaks byte-exact round trips | `OrderedJSON` no-op round-trip test is load-bearing; ship a real sample; preview diff surfaces unintended changes |
| R4 | Unsigned v1 has real Gatekeeper friction on 2026 macOS | Clear install guide; ad-hoc sign; notarization milestone |
| R5 | `import SQLite3` is Apple-SDK-only → not portable to Windows | macOS v1 uses system lib; Windows phase vendors SQLite behind `#if canImport(SQLite3)` |
| R6 | Steam Cloud re-syncs/overwrites an edited save | Surface "disable cloud saves while editing" in the UI |
| R7 | Follower count / gold may be recomputed or overridden by early scripting | Early-scripting warning; viewer lets user verify persistence after reload |
| R8 | Demand is niche; over-promising crowdfunding | Honest framing; tens-to-low-hundreds; sponsorship funds the $99, not a salary |
| R9 | Funding/brand optics of monetizing near someone's work | Loud early credit to FNGarvin + WhiteMinds; pre-launch heads-up; binary stays free |
| R10 | Tier-1 field expansion needs real-save reverse-engineering (unknown paths) | Build the raw JSON tree viewer first; require a CJK + English + DLC save dump; gate risky fields behind warnings |
| R11 | `saveeditor.top` could add DtD and out-reach a native app | Optional WASM/web port as a later second front |

---

*End of design spec. Next step after user review: invoke the `writing-plans` skill to produce the Phase-1 implementation plan.*
