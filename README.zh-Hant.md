<p align="center">
  <img src="docs/images/logo.png" alt="DiveSaveEd" width="160">
</p>

<h1 align="center">DiveSaveEd — macOS 版《潛水員戴夫》存檔修改器</h1>

[English](README.md) · [简体中文](README.zh-Hans.md) · **繁體中文** · [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 14+](https://img.shields.io/badge/Platform-macOS%2014%2B-black.svg)](#requirements)
[![Apple Silicon + Intel](https://img.shields.io/badge/Apple%20Silicon-Intel-lightgrey.svg)](#requirements)

**專為《潛水員戴夫》(Dave the Diver) 打造的原生 macOS 存檔修改器。** 這款遊戲的存檔修改器幾乎清一色
只支援 Windows — 而這是一款真正的 Mac 軟體：開啟存檔、修改、關閉，就這麼單純。不需要 Wine、不用
Cheat Engine、不注入遊戲程序、不需要帳號、不連網路。

<p align="center">
  <img src="docs/images/main-en-light.png" alt="DiveSaveEd 在 macOS 上修改《潛水員戴夫》存檔" width="900">
</p>

## 系統需求

macOS 14 或以上版本，支援 Apple Silicon 與 Intel。適用於 macOS 上的 **Steam** 版遊戲。

> **不支援** Nintendo Switch 與 PlayStation 的存檔 — 那些是主機端存檔，本工具無法讀取。

## 安裝

從 [Releases](../../releases/latest) 下載最新的 `.dmg`，再把程式拖進「應用程式」資料夾。

本程式已經過 Apple 簽署與公證，可以正常開啟 — macOS 只會在第一次執行時，顯示例行的「從網路下載」
確認訊息。

## 功能

**貨幣** — 金幣、貝、匠人之火、研究點數、Cooksta 追蹤者數、信任點數與偽造點數。可以 ±10／100／1000
增減、直接輸入指定數值，或設為最大值。「重設」會把數值還原成你開啟存檔時的狀態。

**批次補滿** — 每一項各按一下，或用 **一鍵全滿** 一次搞定：

| | |
|---|---|
| 餐廳 | 已擁有食材 · 所有食材（自動判斷 DLC） · 二號店分店庫存 · 員工等級 |
| 物品欄 | 一般物品 · 製作材料（魚類零件＋DREDGE 研究零件／骨頭） · 鮫人村 · 農場種子 · 已捕魚類等級 |

**依名稱瀏覽並修改任何單一物品** — 程式內建物品資料庫，你可以直接搜尋真正想要的東西，不必去猜數字 ID。

**所有操作都能回復** — 每個批次操作都可以在程式內回復，每次寫入前都會先建立帶時間戳記的備份，並提供
還原介面讓你回到其中任何一份。

**唯讀的原始存檔檢視器** — 以格式化 JSON 搜尋整份解碼後的存檔。這裡刻意設計成唯讀：手動修改原始數值
可能讓進度旗標的順序錯亂，導致該周目卡死無法繼續。

**多重存檔欄位** — 自動抓出遊戲的每一份存檔，讓你自由選擇。

**四種語言** — English、简体中文、繁體中文、한국어。

<p align="center">
  <img src="docs/images/main-zh-Hant-light.png" alt="繁體中文介面" width="440">
  <img src="docs/images/main-ko-dark.png" alt="한국어 인터페이스 (다크 모드)" width="440">
</p>

## 《潛水員戴夫》Mac 存檔位置在哪裡？

《潛水員戴夫》在 macOS 上的存檔放在這裡：

```
~/Library/Application Support/com.nexon.dave/SteamSData/<steam-id>/
```

有些安裝方式則會改用這個路徑：

```
~/Library/Application Support/nexon/DAVE THE DIVER/SteamSData/
```

兩個位置都會自動檢查 — 不必告訴程式存檔在哪，它自己就找得到。檔案名稱會是 `GameSave_XX_GD.sav`。

`~/Library` 在 Finder 中是隱藏的。想自己打開的話：**Finder → 前往 → 前往檔案夾…**（`⇧⌘G`），貼上
路徑後按 Return。

## ⚠️ Steam Cloud 會默默還原你的修改

這是修改「沒有生效」最常見的原因。Steam 啟動時一發現本機存檔和雲端版本不一致，就會在遊戲載入之前
**用舊的雲端存檔蓋掉你的修改**。請照這個順序操作：

1. **完全關閉《潛水員戴夫》。** 遊戲執行中時，本程式會拒絕寫入。
2. **關閉這款遊戲的 Steam Cloud** — Steam 媒體庫 → 在 **《潛水員戴夫》** 上按右鍵 →
   **內容** → **一般** → 取消勾選 **在 Steam Cloud 保留遊戲存檔**。
3. **修改並儲存。** 程式會自動先寫入一份帶時間戳記的備份。
4. **啟動遊戲。** 這時載入的就是你修改後的版本了。

## 常見問題

### 用了這個工具會被封鎖帳號嗎？

不會。《潛水員戴夫》是單人遊戲，沒有多人連線、沒有排行榜，也沒有任何反作弊軟體。本工具只是在遊戲
關閉時，修改你自己電腦上的一個檔案。它不會附加到遊戲程序，不會讀寫遊戲記憶體，也不會動到遊戲執行檔。

### 為什麼啟動遊戲後，我的修改就不見了？

幾乎都是 Steam Cloud 造成的 — 請看上面那一節。另一個原因是開場教學：教學期間有少數數值是寫死在
腳本裡的，遊戲會直接覆蓋掉。只要過了那個階段，修改就會穩穩保留。

### 中文、韓文或日文的存檔也能用嗎？

可以。含有非 ASCII 文字的存檔都能正確讀取與寫入，不會出現亂碼。

### Intel 版 Mac 能用嗎？

可以 — 本程式是同時支援 Apple Silicon 與 Intel 的通用版本。

### 支援「In the Jungle」DLC 嗎？

支援。DLC 食材都有處理，而且程式只會為存檔中回報為已安裝的 DLC 注入內容。

### 不小心做錯了，可以回復嗎？

可以，而且有兩道保險：**回復上一次修改** 讓你在真正寫入之前，就先在程式內回復批次操作；此外每次寫入
都會建立帶時間戳記的備份，可以從 **從備份還原** 視窗還原。

### 支援 Xbox／Microsoft Store 版嗎？

在 macOS 上不支援 — 那個版本本來就沒有 Mac 版。本工具針對的是 macOS 版 Steam 的存檔位置。

## 這樣安全嗎？

安全性是設計時就定下的前提，不是事後才補的：

- **《潛水員戴夫》執行中時拒絕寫入**，存檔檔案正被其他程式開啟時也一樣。
- **每次寫入前自動建立帶時間戳記的備份**，並提供還原介面。
- **每一項批次操作都可以回復**。
- **寫入前會先顯示變更預覽**。
- **批次補滿會略過易腐的突變魚**（DREDGE 聯名的捕獲物）— 遊戲載入時會丟棄囤積的突變魚，補滿反而會
  清掉你真正的漁獲。
- **以 MIT 授權開放原始碼。** 執行之前，歡迎逐行檢視。

這個程式的存在，是為了讓你能備份、修復自己的單人存檔，並省下重複刷取的時間。

## 不在計畫內

- **Nintendo Switch / PlayStation 存檔** —— 那是加密的主機存檔，本工具無法讀取。
- **Windows 或 Linux 版本** —— 這是一個 Mac 應用程式。
- **任何附加到執行中遊戲的功能** —— 修改器、記憶體修改、覆蓋層。
- **修改遊戲本體的程式碼或素材。**
- **自動更新、遙測或任何連網功能。** 本程式完全不連網，這是刻意的設計保證，而非疏漏。

## 從原始碼建置

```bash
git clone https://github.com/hypery11/DaveTheDiverSaveEditor.git
cd DaveTheDiverSaveEditor
swift test                                  # engine tests
cd App && xcodegen generate                 # generate the Xcode project
xcodebuild -scheme DaveTheDiverSaveEditor test
```

另外還有 `dtdcli`，一個建立在同一套引擎上的無介面命令列工具，方便寫腳本自動化。

## 參與貢獻

歡迎提供翻譯、回報問題與送出修正 — 請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 免責聲明

> 本程式為非官方的玩家自製工具，與 MINTROCKET、Nexon Korea Corporation 或其任何關係企業並無隸屬、
> 授權、背書或贊助關係。「Dave the Diver」（《潛水員戴夫》）及所有相關名稱、標誌與角色，皆為其各自
> 所有者的商標，在此僅作描述性使用，用以指明本工具所搭配的遊戲。本工具只修改你自己電腦上的存檔檔案，
> 不會修改、修補或散布遊戲的任何部分，且 **不含任何遊戲程式碼與遊戲資源**。本程式免費、不含廣告，
> 也不對外販售。使用風險請自行承擔 — 請務必保留備份。

## 授權

MIT — 請見 [LICENSE](LICENSE)。第三方聲明：[NOTICE](NOTICE) 與
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md)。
