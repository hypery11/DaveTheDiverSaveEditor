<p align="center">
  <img src="docs/images/logo.png" alt="DiveSaveEd" width="160">
</p>

<h1 align="center">DiveSaveEd — macOS 版《潜水员戴夫》存档修改器</h1>

[English](README.md) · **简体中文** · [繁體中文](README.zh-Hant.md) · [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 14+](https://img.shields.io/badge/Platform-macOS%2014%2B-black.svg)](#requirements)
[![Apple Silicon + Intel](https://img.shields.io/badge/Apple%20Silicon-Intel-lightgrey.svg)](#requirements)

**macOS 原生的《潜水员戴夫》存档修改器。** 这款游戏的存档修改器几乎清一色只有 Windows 版，Mac 玩家一直没得选
——而这一款是真正的原生 Mac 应用：打开存档文件、改完、写回。它是**存档修改器**，不是 Cheat Engine 那类内存
修改器——不注入进程、不读写游戏内存、不需要账号、全程不联网，也用不着 Wine。

<p align="center">
  <img src="docs/images/main-en-light.png" alt="DiveSaveEd 正在 macOS 上修改《潜水员戴夫》存档" width="900">
</p>

## 系统要求

macOS 14 或更高版本，Apple Silicon 与 Intel 均可。适用于 macOS 上的 **Steam** 版游戏。

> **DiveSaveEd 不是 DaveSaveEd。** 两者名称只差一个字母，也都在改这款游戏的存档，但 DiveSaveEd 是
> 用 Swift 写的 macOS 应用，DaveSaveEd 是 Windows 工具。这个在 Windows 上无法运行。

> **不支持** Nintendo Switch 与 PlayStation 存档——那些是主机存档，本工具无法读取。

## 安装

从 [Releases](../../releases/latest) 下载最新的 `.dmg`，把应用拖进“应用程序”文件夹即可。

应用已经过 Apple 签名与公证，可以正常打开——首次启动时 macOS 会照例弹出“下载自互联网”的确认提示。

## 功能

**货币** — 金币、贝币、匠人之火、研究点数、COOKSTA 粉丝数、信任度与伪造点数。可以按 ±10/100/1000 微调、
直接输入具体数值，或一键拉满。“重置”会还原成你打开存档时的原始数值。

**批量填充** — 每项一键完成，也可以用**一键全部拉满**同时执行全部：

| | |
|---|---|
| 餐厅 | 已有食材 · 全部食材（自动识别 DLC） · 2 号店分店库存 · 员工等级 |
| 背包 | 通用道具 · 制作材料（鱼类部件 + 《渔帆暗涌》研究部件／骨头） · 鲛人村 · 农场种子 · 已捕鱼类等级 |

**按名称浏览并修改任意单个物品** — 应用内置物品数据库，你可以直接搜索真正想要的东西，不用再去翻数字 ID。

**每一步都能回退** — 所有批量操作都可以在应用内撤销，每次写入前都会自动生成带时间戳的备份，并且有专门的恢复
界面，可以回滚到其中任意一份。

**只读的原始数据检视器** — 把整个解码后的存档当作格式化 JSON 来搜索。刻意做成只读：手动改动原始数值可能让
进度标记乱序，导致这一周目卡死、再也推不下去。

**多存档位** — 自动识别游戏里的每一个存档，让你自己挑。

**四种语言** — English、简体中文、繁體中文、한국어。

<p align="center">
  <img src="docs/images/main-zh-Hant-light.png" alt="繁體中文介面" width="440">
  <img src="docs/images/main-ko-dark.png" alt="한국어 인터페이스 (다크 모드)" width="440">
</p>

## 《潜水员戴夫》Mac 存档位置在哪里？

《潜水员戴夫》在 macOS 上把存档放在这里：

```
~/Library/Application Support/com.nexon.dave/SteamSData/<steam-id>/
```

有些安装则改用这个路径：

```
~/Library/Application Support/nexon/DAVE THE DIVER/SteamSData/
```

两个位置都会被自动检查——不用告诉应用存档在哪，它自己就能找到。存档文件名形如 `GameSave_XX_GD.sav`。

`~/Library` 在 Finder（访达）里是隐藏的。想自己打开：**Finder → 前往 → 前往文件夹…**（`⇧⌘G`），粘贴路径后
回车。

## ⚠️ Steam Cloud 会悄悄还原你的修改

这是“改了没生效”最常见的原因。Steam 启动时发现本地存档和云端不一致，会在游戏加载之前就**用旧的云端版本
覆盖掉你的修改**。请按这个顺序操作：

1. **彻底退出《潜水员戴夫》。** 游戏运行期间本应用会拒绝写入。
2. **关闭这款游戏的 Steam Cloud** — Steam 库 → 右键点击 **《潜水员戴夫》** → **属性** → **通用** →
   取消勾选 **将游戏存档保存至 Steam 云**。
3. **修改并保存。** 应用会自动先写一份带时间戳的备份。
4. **启动游戏。** 这时加载的就是你改过的版本了。

## 常见问题

### 用这个会不会被封号？

不会。《潜水员戴夫》是纯单机游戏，没有联机、没有排行榜，也没有任何反作弊程序。本工具只是在游戏关闭时修改你
自己电脑上的一个文件，它从不附加到游戏进程，从不读写游戏内存，也从不改动游戏本体程序。

### 为什么进游戏之后修改就没了？

绝大多数情况是 Steam Cloud——见上一节。另一个原因是开场教程：教程期间有几个数值是脚本写死的，会被游戏覆盖。
过了这一段之后，修改就能稳定保留。

### 中文、韩文、日文的存档能用吗？

可以。含非 ASCII 文本的存档都能正确读写，不会出现乱码。

### Intel 芯片的 Mac 能用吗？

可以——本应用是同时支持 Apple Silicon 与 Intel 的通用二进制版本。

### 支持“In the Jungle”（丛林）DLC 吗？

部分支持，这个限制值得先了解。装了 DLC 的存档可以正常读写——应用不认识的内容会原样保留——批量
填充也只会注入存档中标记为“已安装”的 DLC 内容。但内置物品数据库早于《丛林》，所以丛林专属物品
不会按名称列出，也不在批量填充范围内。更早的 DLC（包括《渔帆暗涌》联动）都已覆盖。

### 改错了还能撤销吗？

能，而且有两道保险：**撤销上一次修改**可以在你真正写入之前撤回批量操作；每次写入还会生成带时间戳的备份，可以
从**从备份恢复**窗口回滚。

### 支持 Xbox / Microsoft Store 版吗？

在 macOS 上不支持——那个版本没有 Mac 版。本工具针对的是 macOS 上的 Steam 存档位置。

## 这样改安全吗？

安全是一开始就定下的设计约束，不是事后补的：

- **《潜水员戴夫》运行期间拒绝写入**，存档文件被其他程序占用时同样拒绝。
- **每次写入前自动生成带时间戳的备份**，并提供恢复界面。
- **批量撤销**，覆盖每一个批量操作。
- 写入任何内容之前都会先给出**更改预览**。
- 批量填充时**跳过易腐的突变鱼**（《渔帆暗涌》联动的捕获物）——游戏在加载时会丢弃囤积的突变鱼，硬填反而会把你
  真正钓到的鱼清掉。
- **基于 MIT 协议开源。** 运行之前，每一行代码你都可以先读一遍。

做这个工具，是为了让你能够备份、修复并“解放”自己的单机存档，不用再重复刷。

## 不在计划内

- **Nintendo Switch / PlayStation 存档** —— 那是加密的主机存档，本工具无法读取。
- **Windows 或 Linux 版本** —— 这是一个 Mac 应用。
- **任何附加到运行中游戏的功能** —— 修改器、内存修改、覆盖层。
- **修改游戏本体的代码或素材。**
- **自动更新、遥测或任何联网功能。** 本应用完全不联网，这是刻意的设计保证，而非疏漏。

## 从源码构建

```bash
git clone https://github.com/hypery11/DaveTheDiverSaveEditor.git
cd DaveTheDiverSaveEditor
swift test                                  # engine tests
cd App && xcodegen generate                 # generate the Xcode project
xcodebuild -scheme DaveTheDiverSaveEditor test
```

另外还有 `dtdcli`——基于同一套引擎的无界面命令行工具，方便写脚本调用。

## 赞助这个项目

DiveSaveEd 是免费的 MIT 许可项目——没有广告、没有付费版、没有任何功能被锁。如果它帮你省下了刷素材
的时间，也想为背后的研究出点力（逆向存档格式、维护物品数据、用游戏自己的本地化文件核对术语），这里
有个链接：

**[fsd.fkey.id](https://fsd.fkey.id/)**

它**只收加密货币**——Base 上的 USDC 最便宜——所以如果你本来没在用，真的不必特地去弄。提一个 bug，
或修正四个语言翻译里的一处错误，对这个项目的价值都比几美元高。

> 唯一的官方赞助链接就是这一个，以及项目网站上的那一个。其他任何地方声称「代收 DiveSaveEd 赞助」
> 都不是我们——fork 或转载的 `.dmg` 里的加密货币地址可以被替换，而且没人看得出来。

## 参与贡献

欢迎提交翻译、问题反馈与修复——详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 免责声明

> 本工具为非官方的粉丝作品，与 MINTROCKET、Nexon Korea Corporation 及其任何关联公司均无隶属关系，也未获得
> 它们的授权、认可或赞助。“Dave the Diver”（《潜水员戴夫》）及所有相关名称、标志与角色均为其各自权利人的
> 商标，此处仅作描述性使用，用于说明本工具适用于哪款游戏。本工具修改的是你自己电脑上的存档文件，不会修改、
> 破解或再分发游戏的任何部分，并且**不含任何游戏代码与游戏素材**。本工具免费、无广告、不出售。使用风险自负
> ——请务必保留备份。

## 许可协议

MIT — 见 [LICENSE](LICENSE)。第三方声明：[NOTICE](NOTICE) 与
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md)。
