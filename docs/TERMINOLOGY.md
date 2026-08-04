# Terminology

Which words this app uses for things the game already names, and why.

Players read the app next to the game. If the app says one thing and the game's own UI says
another, the app looks wrong even when it's working perfectly — so for anything the game
names, the game wins over a good translation of our English.

`Scripts/check_catalog.py` enforces the blocklist at the bottom, and CI runs it on every
push.

## Where these answers come from

Every term below was verified against the game's own shipped localization table — 43
worksheets of parallel `english` / `korean` / `chinese` / `chinesetraditional` columns read
out of an installed build. That is the publisher's localization, so it **settles**
terminology instead of suggesting it.

The extraction tooling is not distributed with this project: it reads the publisher's
copyrighted text, and shipping a turnkey extractor for it is not something a fan tool should
do. What is recorded here — the decisions, the row keys behind them, and the individual terms
— is the durable part, and none of it requires re-running anything.

Four row keys line up exactly with save fields this app edits, which makes them the
strongest evidence obtainable short of a screenshot — they are the labels the game puts on
the very numbers we change:

| row key | en | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|
| `UIText/gold` | Gold | 골드 | 金币 | 金幣 |
| `UIText/bei` | Bei | 베이 | 贝币 | 貝伊 |
| `UIText/researchPoint` | Research Point | 연구포인트 | 研究点数 | 研究點數 |
| `UIText/trustPoint` | **Credit** | 신뢰도 | 信任度 | 信賴度 |

Note `trustPoint`: the shipped English label is "Credit", and Traditional says 信賴度 while
Simplified says 信任度 — the two Chinese locales use *different* words, and picking the
wrong one is exactly the failure this file exists to prevent.

`PlayerInfo.m_FakePoint` has **no row anywhere** in the table. It is an internal field the
game never surfaces, so every locale's label for it is our own description, and the row
subtitle shows the raw JSON path.

When citing a decision below, the row key is given, so a maintainer with the game installed
can confirm any single term without taking the publisher's text anywhere.

## Two rules

1. **Things in the game** — currencies, places, systems — take the game's own wording for
   that locale. Never a translation of our English, never another locale's word.
2. **The app's own chrome** — Save, Backup, Undo, Reset, Open — takes the platform
   convention for that locale (Apple's, for a Mac app).

Where a label is both, rule 1 governs the noun and rule 2 the verb.

## Traditional Chinese (zh-Hant)

This locale had by far the most errors, for a structural reason worth recording: the
translations were produced from the Simplified ones. That works for computing vocabulary,
where the two really are one language in two scripts. **It does not work for this game** —
MINTROCKET ships them as independent localizations with different vocabulary, so converting
characters imports the other region's words.

| English | We ship | Was | Row key |
|---|---|---|---|
| Artisan's Flame | 達人的火花 | ~~匠人之火~~ (the Simplified column) | `Owned_ChefFlame` |
| Sea People / their village | 魚人族 / 魚人村 | ~~鮫人族 / 鮫人村~~ (Simplified) | `scene_MermanVillage` |
| Credit (village trust) | 信賴度 | ~~信任點數~~, then my own wrong fix ~~信任度~~ (Simplified) | `UIText/trustPoint` |
| Bei | 貝伊 | ~~貝~~ | `UIText/bei` |
| Cooksta followers | 追蹤人數 | ~~追蹤者數~~ | `SNS_Grade_Condition_Like` |
| branch restaurant | 分店 | ~~二號店~~ | `ContentsName_SushiBar_Branch` |
| inventory (container) | 背包 | ~~物品欄~~ — zero occurrences in the whole table | `UI_MVSeedInventory` (種子背包) |
| item | 道具 | ~~物品~~ | `item_40001` |
| DREDGE | 《漁帆暗湧》 | ~~DREDGE~~ | Steam DLC title |
| "In the Jungle" DLC | 《叢林》DLC | ~~「In the Jungle」DLC~~ | Steam DLC title |
| Gold | 金幣 | — | `UIText/gold` |
| Research Point | 研究點數 | — (confirmed correct) | `UIText/researchPoint` |
| crafting materials | 製作材料 | — (exactly the game's word) | `UI_DuffWeapon_Pop_Material` |
| ingredients | 食材 | — | `Detail_Tag_TotalCount` (持有食材數) |
| aberration fish | 突變魚 | — | `UI_TravellingMerchant_Title` |
| staff / farm / seed | 員工 / 農場 / 種子 | — | `SushiBar_Staff`, `ContentsName_FarmOpen`, `Crop_Level_0` |

Two notes on things that look like errors but aren't:

* **Cooksta** — the game itself is inconsistent in Traditional: 料理之星 in
  `ContentsName_SnsOpen` and the tutorial, but `COOKSTA` in `PhoneAppName_CookStar` and the
  achievements. We use COOKSTA, matching the phone app's own name.
* **突變 vs 變異** — the build mixes these (the mutated *customer* is 變異客人). Don't
  "fix" one into the other.

### App chrome (Apple zh-TW)

The one that mattered: **`還原` is Undo and `回復` is restore-from-backup.** We had them
backwards, which collides with the system Edit menu — a Mac user reading 「還原」 expects
Undo. `復原` is a third thing (recover deleted) and we don't use it.

| Function | We use | Not |
|---|---|---|
| Undo | 還原 | ~~回復~~ |
| Restore from backup | 回復 | ~~還原~~ |
| Copy | 拷貝 | 複製 (that's Duplicate) |
| Max (button) | 最大值 | 最大 (attributive-only) |
| Save · Reset · OK | 儲存 · 重設 · 好 | 另存新檔 (Microsoft register) |
| Save slot | 存檔格 | ~~存檔欄位~~ (欄位 is a form field) |
| Folder | 檔案夾 when quoting a macOS menu verbatim (前往檔案夾…); 資料夾 in prose | |

The folder split is deliberate: menu quotes must match what the user sees in Finder, and
prose uses the word Taiwanese users actually type into a search box.

## Simplified Chinese (zh-Hans)

Mostly correct already, because it wasn't derived from another locale.

| English | We ship | Was | Row key |
|---|---|---|---|
| Bei | 贝币 | ~~贝~~ | `UIText/bei` |
| Credit (village trust) | 信任度 | ~~信赖点数~~ | `UIText/trustPoint` |
| aberration fish | 突变鱼 | ~~畸变鱼~~ — never appears in the game | `UI_TravellingMerchant_Title` |
| Cooksta | COOKSTA (all caps) | ~~Cooksta~~ | `ContentsName_SnsOpen` |
| item | 道具 | ~~物品~~ | `item_40001` |
| DREDGE | 《渔帆暗涌》 | ~~DREDGE~~ | Steam DLC title |
| Artisan's Flame | 匠人之火 | — **correct here** | `Owned_ChefFlame` |
| Sea People / village | 鲛人族 / 鲛人村 | — **correct here** | `scene_MermanVillage` |
| inventory / followers | 背包 / 粉丝数 | — | `UI_MVSeedInventory`, `SNS_Grade_Condition_Like` |

`匠人之火`, `鲛人村` and `信任度` are **correct in this locale.** The blocklist guards this
direction too, so a well-meaning "consistency" pass can't overwrite them with the
Traditional words.

## Korean (ko)

Korean is the game's original language, so these strings are what everything else was
translated *from*. It was in the best shape of the three — only four errors.

| English | We ship | Was | Row key |
|---|---|---|---|
| Credit (village trust) | 신뢰도 | ~~신뢰도 포인트~~ — 신뢰도 already denotes the level | `UIText/trustPoint` |
| Research Point | 연구포인트 | ~~연구 포인트~~ (closed compound) | `UIText/researchPoint` |
| branch restaurant | 분점 | ~~2호점~~ | `ContentsName_SushiBar_Branch` |
| crafting materials | 제작재료 | ~~제작 재료~~ (closed compound) | `UI_DuffWeapon_Pop_Material` |
| DREDGE | 드렛지 | ~~DREDGE~~ | Steam DLC title |
| Gold / Bei / Artisan's Flame | 골드 / 베이 / 장인의 불꽃 | — all correct | `UIText/gold`, `UIText/bei`, `Owned_ChefFlame` |
| Sea People village | 어인족 마을 | — correct | `scene_MermanVillage` |
| Cooksta / staff / inventory / item | 쿡스타 / 직원 / 인벤토리 / 아이템 | — all correct | `PhoneAppName_CookStar`, `SushiBar_Staff`, `UI_MVSeedInventory`, `item_40001` |

Cooksta is transliterated 쿡스타 in Korean, never left in Latin.

## English (en) — the source language

Wrong English propagates into every translation, so these were fixed at the source, which
meant renaming String Catalog keys and the Swift literals that reference them.

| Was | Now | Why |
|---|---|---|
| Max **Merman** Village | Max Sea People Village | "Merman" appears nowhere in the game's English — it's only the save field name `MermanVillInventory`. `scene_MermanVillage` renders as "Sea People Village". |
| Maxed merman village inventory | Maxed Sea People Village storage | same |
| Sea People (Merman Village) currency | Sea People Village currency | same |
| **Trust Point** | Credit | `UIText/trustPoint`'s shipped English label is "Credit". Odd, but it's what players see; the row subtitle names the field and the concept. |
| Maxed branch (**2nd store**) ingredients | Maxed branch ingredients | `ContentsName_SushiBar_Branch` is "BANCHO SUSHI Branch"; "2nd store" was ours. |
| Stock the **second store's** separate branch counts | Stock the branch's separate ingredient counts | same |

`Research Point` and `Fake Point` stay: the first is the game's own label
(`UIText/researchPoint`), and the second names a field the game never surfaces.

## Still unresolved

**Caught-fish grade.** Our field `CaughtFish[].grade` caps at 5, and no shipped label
matches cleanly: ingredient rank is 級別/등급 (`Ingredients_Sort_Rank`), the DLC fishing
minigame uses 크기/大小 for size, and Cooksta ranks are a separate 級別 scale. We left the
existing wording rather than guess, so this is the one row where the label may not match
the game. A screenshot of the fish-collection card would settle it.

## Sources that look authoritative and aren't

Traditional characters are not evidence of Taiwanese vocabulary. 娛樂計程車
(entertainment14.net), steamXO and gamemad are character-converted mainland guides — they
would have confirmed every one of the wrong Traditional terms above. Nintendo eShop is Hong
Kong only (there is no Taiwan eShop) and its copy diverges from Steam TW (意大利文 vs
義大利文). And Steam ships exactly one 繁體中文 build, so there is no TW/HK in-game split to
choose between — that distinction only affects storefront copy.
