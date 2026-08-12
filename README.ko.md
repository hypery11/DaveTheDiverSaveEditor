<p align="center">
  <img src="docs/images/logo.png" alt="DiveSaveEd" width="160">
</p>

<h1 align="center">DiveSaveEd — macOS용 데이브 더 다이버 세이브 에디터</h1>

[English](README.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md) · **한국어**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 14+](https://img.shields.io/badge/Platform-macOS%2014%2B-black.svg)](#requirements)
[![Apple Silicon + Intel](https://img.shields.io/badge/Apple%20Silicon-Intel-lightgrey.svg)](#requirements)

**《데이브 더 다이버》를 위한 네이티브 macOS 세이브 편집기입니다.** 이 게임의 세이브 에디터는 대부분
Windows 전용이지만, 이 앱은 진짜 Mac 앱입니다. 세이브를 열고, 고치고, 닫습니다. Wine도, Cheat Engine도,
프로세스 인젝션도, 계정도, 네트워크 연결도 없습니다.

<p align="center">
  <img src="docs/images/main-en-light.png" alt="DiveSaveEd editing a Dave the Diver save on macOS" width="900">
</p>

> **Apple 서명 및 공증 완료.** 릴리스마다 SHA-256과 GitHub 빌드 프로버넌스 증명을 공개합니다.
> 열기 전에 직접 확인하실 수 있습니다:
>
> ```bash
> shasum -a 256 DiveSaveEd-macOS-v1.0.1.dmg     # 릴리스 페이지와 비교
> spctl -a -t open --context context:primary-signature -v DiveSaveEd-macOS-v1.0.1.dmg
> ```

## 지원 환경

macOS 14 이상, Apple Silicon 또는 Intel. macOS용 **Steam** 버전 게임에서 동작합니다.

> **DiveSaveEd는 DaveSaveEd가 아닙니다.** 이름이 한 글자 차이이고 둘 다 같은 게임의 세이브를
> 편집하지만, DiveSaveEd는 Swift로 만든 macOS 앱이고 DaveSaveEd는 Windows 도구입니다. 이 앱은
> Windows에서는 실행되지 않습니다.

> Nintendo Switch와 PlayStation 세이브는 **지원하지 않습니다**. 콘솔 세이브라서 이 도구로는 읽을 수
> 없습니다.

## 설치

[Releases](../../releases/latest)에서 최신 `.dmg`를 내려받아 앱을 응용 프로그램 폴더로 끌어다 놓으세요.

Apple의 서명과 공증을 받은 앱이라 그냥 열립니다. 처음 실행할 때 macOS가 "인터넷에서 다운로드한 항목"
확인 창을 한 번 띄웁니다.

## 기능

**재화** — 골드, 베이, 장인의 불꽃, 연구포인트, 쿡스타 팔로워 수, 신뢰도, 가짜 포인트.
±10/100/1000씩 조정하거나, 정확한 값을 직접 입력하거나, 최대치로 설정할 수 있습니다. 「초기화」를 누르면
세이브를 열었을 때의 값으로 되돌아갑니다.

**일괄 채우기** — 항목마다 한 번씩 누르거나, **「모든 채우기 실행」**으로 한꺼번에:

| | |
|---|---|
| 식당 | 보유 식재료 · 모든 식재료(DLC 반영) · 분점 재고 · 직원 레벨 |
| 인벤토리 | 일반 아이템 · 제작재료(물고기 부위 + 드렛지 연구 부품·뼈) · 어인족 마을 · 농장 씨앗 · 잡은 물고기 등급 |

**이름으로 아이템을 검색해 하나씩 편집** — 앱에 아이템 데이터베이스가 들어 있어서, 숫자 ID를 뒤질 필요
없이 원하는 아이템을 이름으로 바로 찾을 수 있습니다.

**모든 작업은 되돌릴 수 있습니다** — 일괄 작업은 앱 안에서 곧바로 되돌릴 수 있고, 저장할 때마다 시각이
기록된 백업이 먼저 만들어지며, 「백업에서 복구」 화면에서 원하는 시점으로 되돌아갈 수 있습니다.

**읽기 전용 원본 뷰어** — 디코딩한 세이브 전체를 정리된 JSON으로 검색할 수 있습니다. 일부러 읽기 전용으로
뒀습니다. 원본 값을 직접 손대면 진행도 플래그가 순서에 맞지 않게 켜져 게임 진행이 막힐 수 있기 때문입니다.

**여러 세이브 슬롯** — 게임이 만든 세이브를 모두 찾아내 목록에서 고를 수 있습니다.

**4개 언어 지원** — English, 简体中文, 繁體中文, 한국어. 여기에 없는 언어를 쓰신다면, 하나 추가하는 건
빌드가 아니라 스프레드시트 작업입니다 — [아래를 보세요](#감사의-말).

<p align="center">
  <img src="docs/images/main-zh-Hant-light.png" alt="繁體中文介面" width="440">
  <img src="docs/images/main-ko-dark.png" alt="한국어 인터페이스 (다크 모드)" width="440">
</p>

## 데이브 더 다이버 세이브 파일 위치 (Mac)

《데이브 더 다이버》는 macOS 세이브를 다음 경로에 저장합니다:

```
~/Library/Application Support/com.nexon.dave/SteamSData/<steam-id>/
```

설치 환경에 따라 이 경로를 쓰기도 합니다:

```
~/Library/Application Support/nexon/DAVE THE DIVER/SteamSData/
```

두 경로 모두 자동으로 확인하므로, 따로 알려주지 않아도 앱이 알아서 세이브를 찾습니다. 파일 이름은
`GameSave_XX_GD.sav` 형식입니다.

`~/Library`는 Finder에서 숨겨져 있습니다. 직접 열려면 **Finder → 이동 → 폴더로 이동…**(`⇧⌘G`)에서 경로를
붙여 넣고 Return을 누르세요.

## ⚠️ Steam Cloud가 편집 내용을 소리 없이 되돌립니다

"편집이 적용되지 않는다"는 문제의 가장 흔한 원인입니다. Steam을 실행하면 로컬 세이브가 클라우드 사본과
다르다는 것을 감지하고, 게임이 켜지기도 전에 **예전 클라우드 버전으로 편집 내용을 덮어씁니다**. 아래
순서를 지키세요:

1. **《데이브 더 다이버》를 완전히 종료하세요.** 게임이 실행 중이면 앱이 저장을 거부합니다.
2. **이 게임의 Steam Cloud를 끄세요** — Steam 라이브러리 → **데이브 더 다이버** 우클릭 →
   **속성** → **일반** → **Steam 클라우드에 게임 저장 보관**(Keep game saves in the Steam Cloud) 체크 해제.
3. **편집하고 저장하세요.** 시각이 기록된 백업이 자동으로 먼저 만들어집니다.
4. **게임을 실행하세요.** 이제 편집한 세이브가 그대로 불러와집니다.

## 자주 묻는 질문

### 이거 쓰면 계정이 정지되나요?

아니요. 《데이브 더 다이버》는 멀티플레이도, 리더보드도, 안티치트 프로그램도 없는 싱글 플레이 게임입니다.
이 도구는 게임이 꺼져 있는 동안 내 컴퓨터에 있는 파일 하나를 편집할 뿐입니다. 게임 프로세스에 붙지 않고,
게임 메모리를 읽거나 쓰지 않으며, 게임 실행 파일도 건드리지 않습니다.

### 게임을 켰더니 편집한 내용이 사라졌어요

거의 대부분 Steam Cloud 때문입니다. 위 항목을 참고하세요. 다른 원인은 초반 튜토리얼입니다. 튜토리얼
구간에서는 몇몇 값이 스크립트로 고정돼 있어 게임이 다시 덮어씁니다. 이 구간만 지나면 편집 내용이
안정적으로 유지됩니다.

### 한국어·중국어·일본어 세이브에서도 되나요?

네. ASCII가 아닌 문자가 들어간 세이브도 글자가 깨지지 않고 정확하게 읽고 씁니다.

### Intel Mac에서도 되나요?

네. Apple Silicon과 Intel을 모두 지원하는 유니버설 빌드입니다.

### "In the Jungle" DLC도 지원하나요?

부분적으로 지원하며, 이 한계는 미리 알아두는 편이 좋습니다. DLC가 설치된 게임의 세이브도 정상적으로
읽고 쓰며, 앱이 모르는 데이터는 그대로 보존됩니다. 일괄 채우기도 세이브에 설치된 것으로 기록된
DLC의 콘텐츠만 넣습니다. 다만 내장 아이템 데이터베이스가 "인 더 정글"보다 앞서 만들어졌기 때문에,
정글 전용 아이템은 이름으로 표시되지 않고 일괄 채우기에도 포함되지 않습니다. 그 이전 DLC(드렛지
컬래버 포함)는 모두 지원합니다.

### 실수로 한 작업을 되돌릴 수 있나요?

네, 두 겹으로 안전장치가 있습니다. **「마지막 편집 되돌리기」**는 저장하기 전에 일괄 작업을 앱 안에서
되돌리고, 저장할 때마다 시각이 기록된 백업이 만들어져 **「백업에서 복구」** 창에서 언제든 복구할 수
있습니다.

### Xbox / Microsoft Store 버전에서도 되나요?

macOS에서는 안 됩니다. 그 버전은 Mac으로 나오지 않았습니다. 이 도구는 macOS Steam 세이브 경로를 대상으로
합니다.

## 안전한가요?

안전성은 나중에 덧붙인 것이 아니라 설계 조건입니다:

- **《데이브 더 다이버》가 실행 중이거나** 세이브 파일이 다른 곳에서 열려 있으면 **저장을 거부합니다.**
- **저장 전 시각이 기록된 백업을 자동으로 생성**하고, 복구 화면을 제공합니다.
- 모든 일괄 작업에 대한 **일괄 되돌리기**.
- 기록하기 전에 확인하는 **「변경 사항 검토」** 화면.
- 일괄 채우기에서 **사라지는 돌연변이 물고기(드렛지 컬래버 어종)는 건너뜁니다.** 게임이 세이브를 불러올 때
  쌓아둔 돌연변이 물고기를 버리기 때문에, 채워 넣으면 실제로 잡아둔 물고기까지 날아갑니다.
- **MIT 라이선스 오픈소스.** 실행하기 전에 코드를 한 줄씩 확인할 수 있습니다.

이 도구는 여러분의 싱글 플레이 세이브를 백업하고, 망가진 세이브를 되살리고, 지겨운 노가다를 건너뛰기 위해
존재합니다.

## 계획에 없는 것

- **Nintendo Switch / PlayStation 세이브** — 암호화된 콘솔 세이브라 이 도구로는 읽을 수 없습니다.
- **Windows 또는 Linux 빌드** — 이 앱은 Mac 전용입니다.
- **실행 중인 게임에 붙는 기능** — 트레이너, 메모리 수정, 오버레이.
- **게임 자체의 코드나 에셋 수정.**
- **자동 업데이트, 텔레메트리 등 네트워크 기능.** 이 앱은 네트워크 요청을 전혀 하지 않으며,
  이는 누락이 아니라 의도된 설계 보장입니다.

## 소스에서 빌드하기

```bash
git clone https://github.com/hypery11/DaveTheDiverSaveEditor.git
cd DaveTheDiverSaveEditor
swift test                                  # engine tests
cd App && xcodegen generate                 # generate the Xcode project
xcodebuild -scheme DaveTheDiverSaveEditor test
```

같은 엔진을 쓰는 헤드리스 CLI인 `dtdcli`도 함께 들어 있어 스크립트 자동화에 활용할 수 있습니다.

## 프로젝트 후원하기

<p align="center">
  <a href="https://fsd.fkey.id/"><img src="docs/images/support-banner-ko.png" alt="DiveSaveEd — 언제나 무료, 하지만 공짜는 아닙니다" width="880"></a>
</p>

<p align="center">
  <a href="https://fsd.fkey.id/"><img src="docs/images/btn-support-ko.png" alt="DiveSaveEd 후원하기" height="48"></a>
</p>

DiveSaveEd는 무료이며 MIT 라이선스입니다. 광고도, 유료 버전도, 결제로 막아둔 기능도 없고 앞으로도
그렇습니다. 다만 쓰는 게 무료인 것과 만드는 게 무료인 것은 다릅니다.

| | |
|---|---|
| **연 99달러** | Apple 개발자 멤버십. macOS가 "확인되지 않은 개발자" 경고 없이 이 앱을 그냥 열어 주는 이유는 이것뿐입니다. |
| **게임 패치마다** | 아이템·물고기 데이터베이스를 다시 만들어야 일괄 채우기가 계속 정확합니다. |
| **언어마다** | 게임 내 용어를 우리 영어에서 번역하지 않고, 게임이 실제로 출시한 현지화 데이터와 대조합니다. |

돈이 정확히 무엇을 메우는지 알고 싶다면 가장 구체적인 예가 있습니다. **아이템 데이터베이스는
"In the Jungle" DLC 이전에서 멈춰 있습니다. 제가 그 DLC를 사지 못했기 때문입니다.** 정글 전용
아이템은 이름으로 찾을 수도 없고 일괄 채우기에도 포함되지 않습니다. 돈으로 실제로 메워지는 구멍입니다.

**돈보다 도움이 되는 것.** 진심입니다 — 아래 중 무엇이든 몇 달러보다 이 프로젝트에 더 큰 도움이 됩니다.

- [버그 제보](../../issues/new/choose) — 앱의 도움말 메뉴가 세부 정보를 대신 채워 줍니다
- [번역 수정](CONTRIBUTING.md) — 네 가지 언어로 나오지만 제가 잘하는 건 두 개뿐입니다
- Mac으로 이 게임을 하는 사람에게 알려 주기
- 저장소에 별을 눌러 다른 사람이 찾을 수 있게 하기

> **공식 후원 링크는 위의 것과 [프로젝트 사이트](https://hypery11.github.io/DaveTheDiverSaveEditor/ko/support/)에 있는 것뿐입니다.**
> 다른 곳에서 "DiveSaveEd를 위해" 모금한다면 저희가 아닙니다 — 포크나 재배포된 `.dmg`의 암호화폐
> 주소는 아무도 알아채지 못하게 바꿔치기할 수 있습니다.

## 기여하기

번역, 버그 제보, 수정 모두 환영합니다 — [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

버그인지 확실하지 않거나 그냥 물어보고 싶을 때는 [Discussions](https://github.com/hypery11/DaveTheDiverSaveEditor/discussions)를 이용하세요. 한국어,
中文, English 모두 똑같이 환영하며 — issue에서도 마찬가지입니다 — 며칠 안에 첫 답변을 드립니다.

## 감사의 말

**번역과 수정** — 아직 아무도 없습니다. 여기가 여러분의 이름이 들어갈 자리입니다.
[번역 issue](../../issues/new?template=translation.yml)가 어떤 이름으로 표기되길 원하는지 묻는데,
바로 이 항목을 위한 질문입니다. 프로그래머가 아니어도 되고 Xcode도 필요 없습니다 —
[CONTRIBUTING.md](CONTRIBUTING.md)에 스프레드시트만으로 끝나는 경로가 있습니다.

**이 프로젝트가 딛고 선 것들** — [FNGarvin/DaveSaveEd](https://github.com/FNGarvin/DaveSaveEd)
(MIT). 이 프로젝트의 참조 데이터베이스가 여기서 생성되고, 세이브 경로 지식과 기능 구성도 여기서
왔습니다. 그리고 [WhiteMinds/dave-diver-expansion](https://github.com/WhiteMinds/dave-diver-expansion) —
문자 단위 XOR 코덱에 대한 이 저장소의 이해 덕분에 이 편집기가 한국어·중국어·일본어 세이브를
망가뜨리지 않습니다. 전체 출처 표기는 [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md)에 있습니다.

## 면책 조항

팬이 만든 비공식 도구입니다. MINTROCKET, NEXON과 아무 관계가 없습니다. "Dave the Diver"(데이브 더
다이버)는 그들의 이름이고, 여기서는 어떤 게임을 편집하는 도구인지 밝히려고 썼을 뿐입니다. 사용자
본인 컴퓨터의 세이브 파일을 읽고 쓰며, 게임 코드와 게임 에셋은 전혀 들어 있지 않습니다.

## 라이선스

MIT — [LICENSE](LICENSE)를 참고하세요. 서드파티 고지:
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).
