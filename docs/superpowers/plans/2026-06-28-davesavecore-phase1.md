# DaveSaveCore (Phase 1) Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build the pure-Swift DaveSaveCore library: char-level save codec, lexeme-preserving OrderedJSON, SaveDocument currency+ingredient editing, ReferenceDB, macOS save discovery, and persistent backups — all TDD with Swift Testing.

**Architecture:** A SwiftPM library 'DaveSaveCore' (.macOS(.v14), Swift 6) with no UI deps; char-level UTF-16 XOR codec; a lexeme-preserving JSON DOM so unedited tokens are byte-identical; SQLite reference data via the system import SQLite3.

**Tech Stack:** Swift 6.0, SwiftPM, Swift Testing, system SQLite3, Foundation.

## Global Constraints

GLOBAL CONSTRAINTS (every task implicitly includes these; copy values verbatim):
- swift-tools-version:6.0 ; platform .macOS(.v14) ; arm64 ; 100% pure Swift (no C/C++).
- Codec: char-level XOR over UTF-16 code units, key "GameData" (key16 = Array("GameData".utf16)); operate on [UInt16], NOT String, during XOR.
- OrderedJSON: lexeme-preserving; compact serialize (no whitespace); decode->parse->serialize with zero edits must be byte-identical for compact input.
- Currency clamp = 999_999_999. Artisan's Flame "Max" button value (UI, later) = 999_999. Follower count UNCLAMPED (UI Max = 99_999).
- Ingredient tier map: MaxCount>=9999 -> 6666 ; >=999 -> 666 ; >=99 -> 66 ; else skip (return 0). DLC map {1:14252001, 3:14252201, 5:14252401} compared vs GameInfo.installedDLCs.
- New ingredient entry shape (Max-All inject), in order: ingredientsID(int), parentID(int), count(int target), level=1, branchCount=0, isNew=true, placeTagMask=1, lastGainTime="04/01/2025 12:34:56", lastGainGameTime="10/03/2022 08:30:52".
- Save paths: PlayerInfo.m_Gold, PlayerInfo.m_Bei, PlayerInfo.m_ChefFlame, SNSInfo.m_Follow_Count, Ingredients.<id>.count, GameInfo.installedDLCs.
- macOS save roots (VERIFIED on a real Apple Silicon install 2026-06-28 — the PRIMARY is com.nexon.dave/SteamSData, NOT nexon/DAVE THE DIVER): ~/Library/Application Support/com.nexon.dave/SteamSData/<steamid>/ (primary) ; ~/Library/Application Support/nexon/DAVE THE DIVER/SteamSData/ ; ~/Library/Application Support/nexon/DAVE THE DIVER/SData/ . Filenames: GameSave*_GD.sav and m_*.sav. Discovery scans each root + each immediate ALL-ASCII-DIGIT subfolder; newest contentModificationDate.
- Backups: ~/Library/Application Support/<bundleID>/Backups/<stem>_yyyyMMdd_HHmmss.sav (en_US_POSIX, local time). Atomic write via Data.write(options:.atomic).
- SQLite via system 'import SQLite3'; reference.sqlite is a Bundle.module resource.
- Commits: NO "Co-Authored-By", NO AI/Claude/LLM mentions. Conventional commit messages (feat:/test:/chore:).
- Tests: Swift Testing. Synthetic/anonymized fixtures only — never a real user's save. Include CJK fixture and a non-11090001 farm-animal fixture.

## Interface Contract

LOCKED INTERFACE CONTRACT (use these EXACT names/signatures; do not invent variants).

Package: SwiftPM swift-tools-version:6.0, platform .macOS(.v14), 100% Swift, library product "DaveSaveCore". macOS-only v1 uses the SDK system SQLite via 'import SQLite3' (works in SwiftPM on macOS; no custom system target). reference.sqlite ships as a Bundle.module resource. Tests use Swift Testing ('import Testing', @Test, #expect/#require).

```swift
// SaveCodec.swift  (pure, no I/O; char-level UTF-16 XOR with key "GameData")
public enum SaveCodec {
  public static func decode(_ data: Data) -> String   // .sav bytes -> JSON text
  public static func encode(_ json: String) -> Data   // JSON text -> .sav bytes
}

// OrderedJSON.swift  (lexeme-preserving DOM; compact serialize; byte-identical for unedited compact input)
public indirect enum OrderedJSON: Equatable {
  case object([Member])
  case array([OrderedJSON])
  case scalar(String)   // VERBATIM source lexeme of the value token: numbers/bool/null as-is ("999999999","true","null"); strings INCLUDING surrounding quotes & escapes ("\"abc\"")
}
public struct Member: Equatable {
  public var keyLexeme: String      // verbatim key token INCLUDING quotes, e.g. "\"m_Gold\""
  public var value: OrderedJSON
  public init(keyLexeme: String, value: OrderedJSON)
  public var key: String { get }    // decoded key: quotes stripped + JSON escapes resolved
}
public enum JSONParseError: Error, Equatable { case unexpectedEnd; case unexpectedCharacter(Int); case invalidNumber(Int) }
public extension OrderedJSON {
  static func parse(_ text: String) throws -> OrderedJSON     // recursive descent, captures verbatim lexemes
  func serialized() -> String                                 // compact, no whitespace, lexemes verbatim
  func value(at path: [String]) -> OrderedJSON?               // walk object members by decoded key
  mutating func setScalar(at path: [String], lexeme: String) -> Bool   // replace a scalar leaf; false if path missing/not scalar
  mutating func setMember(at path: [String], member: Member) -> Bool   // set or append a member in the object at path (used for ingredient insert)
}

// ReferenceDB.swift  (read-only SQLite over the ingredient/items reference data)
public struct IngredientRow: Equatable { public let id: Int; public let parentID: Int; public let maxCount: Int; public let dlcType: Int }
public final class ReferenceDB {
  public init(url: URL) throws                  // sqlite3_open_v2 READONLY
  public static func bundled() throws -> ReferenceDB    // opens Bundle.module url for "reference" sqlite
  public func maxCount(itemDataID: Int) -> Int?         // SELECT MaxCount FROM Items WHERE ItemDataID=?
  public func allIngredients() -> [IngredientRow]       // SELECT I.TID, T.TID, T.MaxCount, T.DLCType FROM Ingredients I JOIN Items T ON I.TID=T.ItemDataID
}

// SaveDocument.swift  (load/edit/write API over a parsed save)
public struct FieldChange: Equatable { public let path: String; public let oldValue: String; public let newValue: String }
public struct SaveDocument {
  public static func load(_ data: Data) throws -> SaveDocument   // SaveCodec.decode -> OrderedJSON.parse; throws JSONParseError on invalid JSON
  public func encoded() -> Data                                  // serialized -> SaveCodec.encode
  public var gold: Int64 { get } ; public var bei: Int64 { get } ; public var artisansFlame: Int64 { get } ; public var followerCount: Int64 { get }
  public mutating func setGold(_ v: Int64)            // clamp to 999_999_999
  public mutating func setBei(_ v: Int64)             // clamp to 999_999_999
  public mutating func setArtisansFlame(_ v: Int64)   // clamp to 999_999_999
  public mutating func setFollowerCount(_ v: Int64)   // NO clamp
  public mutating func maxOwnedIngredients(using ref: ReferenceDB)
  public mutating func maxAllIngredients(using ref: ReferenceDB)
  public func pendingChanges() -> [FieldChange]       // diff current vs the originally-loaded snapshot, over known editable paths
}

// SaveLocator.swift  (macOS save discovery)
public struct SaveCandidate: Equatable { public let fileURL: URL; public let directoryURL: URL; public let modified: Date }
public enum SaveLocator {
  public static func candidateRoots(home: URL) -> [URL]   // the 3 known nexon roots
  public static func newestSave(fileManager: FileManager = .default, home: URL? = nil) -> SaveCandidate?
}

// BackupStore.swift  (persistent timestamped backups + atomic write)
public enum BackupStore {
  public static func backupDirectory(bundleID: String, home: URL? = nil) -> URL
  @discardableResult public static func backup(original: URL, bundleID: String, now: Date = Date(), home: URL? = nil) throws -> URL
  public static func listBackups(bundleID: String, home: URL? = nil) -> [URL]    // newest first
  public static func writeAtomically(_ data: Data, to url: URL) throws
}
```

## Tasks

All paths below are relative to the **new repo root** (`dave-the-diver-save-editor/`, a fresh git repo with no upstream history — created here as a sibling of the upstream reference clone `…/DaveSaveEd/`). Run every command from that repo root. The upstream clone is referenced *only* by the Task 1b generator script.

---

### Task 1: Package scaffold — `DaveSaveCore` SwiftPM package, resource wiring & smoke test

**Files:**
- Create `Package.swift`
- Create `.gitignore`
- Create `Sources/DaveSaveCore/DaveSaveCore.swift`
- Create `Sources/DaveSaveCore/Resources/reference.sqlite` (placeholder; replaced in Task 1b)
- Test `Tests/DaveSaveCoreTests/SmokeTests.swift`

**Interfaces:**
- *Consumes:* nothing (root task).
- *Produces:* SwiftPM library product **`DaveSaveCore`**, `swift-tools-version:6.0`, platform `.macOS(.v14)`, with a `DaveSaveCoreTests` Swift Testing target. Module exposes `public enum DaveSaveCore { static let version: String }` and `internal enum ReferenceResource { static var url: URL? }` (resolves `Bundle.module`'s `reference.sqlite` — **ReferenceDB.bundled() in a later task builds on this**). `Bundle.module` carries `reference.sqlite` via `.process("Resources")`. The target links the system SQLite via `.linkedLibrary("sqlite3")` so the later `import SQLite3` in `ReferenceDB.swift` links with no manifest churn.

- [ ] **Step 1: Initialize the repo.**
  ```bash
  git init -b main
  mkdir -p Sources/DaveSaveCore/Resources Tests/DaveSaveCoreTests Scripts
  ```

- [ ] **Step 2: Write `.gitignore`.** (Note: does NOT ignore `*.sqlite` — `reference.sqlite` is a shipped resource and must be committed.)
  ```gitignore
  # Swift Package Manager
  .build/
  .swiftpm/
  Package.resolved

  # Xcode
  DerivedData/
  xcuserdata/
  *.xcuserstate
  *.xcodeproj/xcuserdata/
  *.xcworkspace/xcuserdata/

  # macOS
  .DS_Store

  # Logs / temp
  *.log
  *.bak
  ```

- [ ] **Step 3: Write `Package.swift`.**
  ```swift
  // swift-tools-version:6.0
  import PackageDescription

  let package = Package(
      name: "DaveSaveCore",
      platforms: [
          .macOS(.v14)
      ],
      products: [
          .library(name: "DaveSaveCore", targets: ["DaveSaveCore"])
      ],
      targets: [
          .target(
              name: "DaveSaveCore",
              resources: [
                  .process("Resources")
              ],
              linkerSettings: [
                  // macOS-only v1: link the Apple SDK's system SQLite so the
                  // later `import SQLite3` in ReferenceDB resolves with no edit here.
                  .linkedLibrary("sqlite3")
              ]
          ),
          .testTarget(
              name: "DaveSaveCoreTests",
              dependencies: ["DaveSaveCore"]
          )
      ]
  )
  ```

- [ ] **Step 4: Write the module marker `Sources/DaveSaveCore/DaveSaveCore.swift`.**
  ```swift
  import Foundation

  /// Module marker + version for the pure-Swift DaveSaveCore package.
  ///
  /// The concrete types (`SaveCodec`, `OrderedJSON`, `ReferenceDB`,
  /// `SaveDocument`, `SaveLocator`, `BackupStore`) are added by later tasks.
  public enum DaveSaveCore {
      /// Semantic version of the core library.
      public static let version = "0.1.0"
  }

  /// Locates the bundled, read-only reference database resource.
  ///
  /// `ReferenceDB.bundled()` (later task) reuses this to obtain the URL it
  /// opens with `sqlite3_open_v2(..., SQLITE_OPEN_READONLY, ...)`.
  internal enum ReferenceResource {
      /// URL of `reference.sqlite` inside `Bundle.module`, or `nil` if absent.
      static var url: URL? {
          Bundle.module.url(forResource: "reference", withExtension: "sqlite")
      }
  }
  ```

- [ ] **Step 5: Create the placeholder `reference.sqlite` so the declared resource exists and the package builds.** Task 1b overwrites this file with the real 563/305-row database.
  ```bash
  rm -f Sources/DaveSaveCore/Resources/reference.sqlite
  sqlite3 Sources/DaveSaveCore/Resources/reference.sqlite \
    "CREATE TABLE _placeholder(note TEXT); INSERT INTO _placeholder VALUES('replaced by Scripts/gen_refdb.sh in Task 1b');"
  ```

- [ ] **Step 6: Write the smoke test `Tests/DaveSaveCoreTests/SmokeTests.swift`.** Proves the Swift Testing runner executes *and* that the `reference.sqlite` resource is wired into `Bundle.module`.
  ```swift
  import Foundation
  import Testing
  @testable import DaveSaveCore

  @Suite("Smoke")
  struct SmokeTests {
      @Test("Swift Testing runner executes")
      func runnerExecutes() {
          #expect(DaveSaveCore.version == "0.1.0")
      }

      @Test("reference.sqlite is bundled in Bundle.module")
      func referenceResourceIsPresent() throws {
          let url = try #require(ReferenceResource.url)
          #expect(FileManager.default.fileExists(atPath: url.path))
      }
  }
  ```

- [ ] **Step 7: Run the test suite.**
  ```bash
  swift test --filter SmokeTests
  ```
  Expected: **PASS** (2 tests pass; build succeeds with the resource bundled and `-lsqlite3` linked).

- [ ] **Step 8: Commit.**
  ```bash
  git add .gitignore Package.swift \
    Sources/DaveSaveCore/DaveSaveCore.swift \
    Sources/DaveSaveCore/Resources/reference.sqlite \
    Tests/DaveSaveCoreTests/SmokeTests.swift
  git commit -m "chore: scaffold DaveSaveCore SwiftPM package"
  ```

---

### Task 1b: Reference data — extract `reference.sql` + build `reference.sqlite` from upstream

**Files:**
- Create `Scripts/inflate_embedded_sql.py`
- Create `Scripts/gen_refdb.sh`
- Create `reference.sql` (checked-in, human-diffable SQL dump — OQ-C default)
- Modify `Sources/DaveSaveCore/Resources/reference.sqlite` (placeholder → real 563/305 DB)

**Interfaces:**
- *Consumes:* the package layout + `Sources/DaveSaveCore/Resources/` from Task 1; the upstream `embedded_sql.h` (default `${repo}/../DaveSaveEd/embedded_sql.h`; overridable via arg 1 or `UPSTREAM_HEADER`).
- *Produces:* populated `reference.sqlite` with verified schema/rows the later `ReferenceDB.swift` relies on: table `Items(... ItemDataID INTEGER, MaxCount INTEGER, DLCType INTEGER ...)` and table `Ingredients(TID INTEGER PRIMARY KEY, Type INTEGER)`; row counts **563 Items / 305 Ingredients**; the two contract queries verified working — `SELECT MaxCount FROM Items WHERE ItemDataID=?` and `SELECT I.TID, T.TID, T.MaxCount, T.DLCType FROM Ingredients I JOIN Items T ON I.TID=T.ItemDataID`. Also produces the regeneration tooling (`Scripts/`) and the checked-in `reference.sql`.

> Decompression approach (verified against the real blob): `embedded_sql.h` stores `const unsigned char embedded_sql_compressed[]` — a raw **zlib** stream (magic `0x78 0xda`). The Python helper reads that header file, regex-extracts the `0xNN` byte literals, `zlib.decompress`es them to the 139,056-byte plaintext SQL, and writes it to stdout. `gen_refdb.sh` pipes that into `sqlite3 reference.sqlite`. (Mirrors upstream `DaveSaveEd.cpp` `inflate(...Z_FINISH...)` → `sqlite3_exec`, but produces an on-disk file to ship as a resource instead of an `:memory:` DB.)

- [ ] **Step 1: Write the decompression helper `Scripts/inflate_embedded_sql.py`.**
  ```python
  #!/usr/bin/env python3
  """Inflate the zlib-compressed `embedded_sql_compressed[]` blob from the
  upstream `embedded_sql.h` and emit the plaintext SQL dump on stdout."""
  import re
  import sys
  import zlib


  def main() -> int:
      if len(sys.argv) != 2:
          sys.stderr.write("usage: inflate_embedded_sql.py <path-to-embedded_sql.h>\n")
          return 2
      header = sys.argv[1]
      with open(header, "r", encoding="utf-8", errors="strict") as fh:
          src = fh.read()
      m = re.search(r"embedded_sql_compressed\[\]\s*=\s*\{(.*?)\};", src, re.S)
      if not m:
          sys.stderr.write("error: embedded_sql_compressed[] array not found\n")
          return 1
      nums = re.findall(r"0x[0-9a-fA-F]{2}", m.group(1))
      if not nums:
          sys.stderr.write("error: no hex byte literals found in array\n")
          return 1
      blob = bytes(int(tok, 16) for tok in nums)
      sql = zlib.decompress(blob)            # raw zlib stream (0x78 0xda header)
      sys.stdout.buffer.write(sql)
      return 0


  if __name__ == "__main__":
      raise SystemExit(main())
  ```

- [ ] **Step 2: Write the generator `Scripts/gen_refdb.sh`.** It rebuilds `reference.sql` and `reference.sqlite`, deletes the target DB first (re-running `sqlite3 file < dump` into an existing DB fails with `table … already exists`), and verifies the row counts.
  ```bash
  #!/usr/bin/env bash
  #
  # gen_refdb.sh — regenerate the bundled reference database from the upstream
  # DaveSaveEd `embedded_sql.h` zlib blob.
  #
  #   1. inflate embedded_sql_compressed[]  ->  reference.sql            (checked in)
  #   2. sqlite3 reference.sqlite < reference.sql                        (shipped resource)
  #   3. verify row counts (563 Items / 305 Ingredients)
  #
  # Usage:
  #   Scripts/gen_refdb.sh [path/to/embedded_sql.h]
  #   UPSTREAM_HEADER=/path/to/embedded_sql.h Scripts/gen_refdb.sh
  #
  set -euo pipefail

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

  HEADER="${1:-${UPSTREAM_HEADER:-${ROOT}/../DaveSaveEd/embedded_sql.h}}"
  SQL_OUT="${ROOT}/reference.sql"
  DB_OUT="${ROOT}/Sources/DaveSaveCore/Resources/reference.sqlite"

  if [[ ! -f "${HEADER}" ]]; then
      echo "error: upstream header not found: ${HEADER}" >&2
      echo "       pass the path as arg 1 or set UPSTREAM_HEADER=" >&2
      exit 1
  fi

  echo "inflating ${HEADER} -> ${SQL_OUT}"
  python3 "${SCRIPT_DIR}/inflate_embedded_sql.py" "${HEADER}" > "${SQL_OUT}"

  echo "building ${DB_OUT}"
  mkdir -p "$(dirname "${DB_OUT}")"
  rm -f "${DB_OUT}"                       # sqlite3 errors if it imports into an existing schema
  sqlite3 "${DB_OUT}" < "${SQL_OUT}"

  items=$(sqlite3 "${DB_OUT}" 'SELECT COUNT(*) FROM Items;')
  ingredients=$(sqlite3 "${DB_OUT}" 'SELECT COUNT(*) FROM Ingredients;')
  echo "Items=${items} Ingredients=${ingredients}"

  if [[ "${items}" != "563" || "${ingredients}" != "305" ]]; then
      echo "error: unexpected row counts (want 563 Items / 305 Ingredients)" >&2
      exit 1
  fi
  echo "ok: reference database regenerated."
  ```

- [ ] **Step 3: Make the scripts executable.**
  ```bash
  chmod +x Scripts/inflate_embedded_sql.py Scripts/gen_refdb.sh
  ```

- [ ] **Step 4: Generate `reference.sql` + populate `reference.sqlite`.**
  ```bash
  Scripts/gen_refdb.sh
  ```
  Expected: **PASS** — prints `Items=563 Ingredients=305` and `ok: reference database regenerated.` (exit 0). `reference.sql` is 139,056 bytes; `Sources/DaveSaveCore/Resources/reference.sqlite` now holds the real data.

- [ ] **Step 5: Confirm the package still builds with the real resource and the contract queries work.**
  ```bash
  swift test --filter SmokeTests
  sqlite3 Sources/DaveSaveCore/Resources/reference.sqlite \
    "SELECT MaxCount FROM Items WHERE ItemDataID=1020201; \
     SELECT I.TID, T.TID, T.MaxCount, T.DLCType FROM Ingredients I JOIN Items T ON I.TID=T.ItemDataID LIMIT 1;"
  ```
  Expected: **PASS** — `swift test` green (resource still bundled); the `sqlite3` check prints `9999` then a joined row (e.g. `1021045|1010020|9999|0`), proving both `ReferenceDB` queries resolve against the shipped schema.

- [ ] **Step 6: Commit.**
  ```bash
  git add Scripts/inflate_embedded_sql.py Scripts/gen_refdb.sh \
    reference.sql Sources/DaveSaveCore/Resources/reference.sqlite
  git commit -m "chore: generate bundled reference.sqlite from upstream SQL blob"
  ```

---

### Task 2: SaveCodec — char-level (UTF-16 code-unit) XOR

**Files:**
- Test (create): `Tests/DaveSaveCoreTests/SaveCodecTests.swift`
- Create: `Sources/DaveSaveCore/SaveCodec.swift`

**Interfaces:**
- **Consumes:** the SwiftPM package + targets from Task 1 — library product `DaveSaveCore` (target `Sources/DaveSaveCore`) and test target `DaveSaveCoreTests` (`import Testing`). No code symbols consumed.
- **Produces (later tasks rely on these EXACT signatures):**
  ```swift
  public enum SaveCodec {
    public static func decode(_ data: Data) -> String   // .sav bytes -> JSON text
    public static func encode(_ json: String) -> Data   // JSON text -> .sav bytes
  }
  ```
  Used by Task "SaveDocument": `SaveDocument.load` calls `SaveCodec.decode`; `SaveDocument.encoded()` calls `SaveCodec.encode`.

Codec model (spec §5.1–§5.3): the on-disk `.sav` is the UTF-8 encoding of the per-code-unit-XOR'd JSON string. XOR is over **UTF-16 code units** (`key16 = Array("GameData".utf16)`, key index cycling per code unit), operating on `[UInt16]`, never on `Swift.String`. This mirrors the game exactly; decode→(no edit)→encode is byte-identical by construction, and CJK is correct with no `BYPASSED_HEX` hack.

- [ ] **Step 1: Write the failing tests (RED).** Create `Tests/DaveSaveCoreTests/SaveCodecTests.swift`. Covers (a) the hand-computed tiny vector, (b) an `encode(decode(x)) == x` round-trip on a synthetic `.sav` fixture, and (c) a CJK round-trip (`白毛鸡`, on a non-`11090001` farm animal) asserting zero `U+FFFD`.
  ```swift
  import Testing
  import Foundation
  @testable import DaveSaveCore

  @Suite struct SaveCodecTests {

      // (a) Hand-computed tiny vector — plaintext "ab" XOR key "GameData":
      //     'a'(0x61) ^ 'G'(0x47) = 0x26 ; 'b'(0x62) ^ 'a'(0x61) = 0x03.
      @Test func handVectorEncode() {
          #expect(SaveCodec.encode("ab") == Data([0x26, 0x03]))
      }

      @Test func handVectorDecode() {
          #expect(SaveCodec.decode(Data([0x26, 0x03])) == "ab")
      }

      // key16 is exactly the ASCII code units of "GameData".
      @Test func keyIsGameDataCodeUnits() {
          #expect(Array("GameData".utf16) == [0x47, 0x61, 0x6D, 0x65, 0x44, 0x61, 0x74, 0x61])
      }

      // (b) Round-trip on a JSON-ish fixture. A real `.sav` is by definition an
      //     `encode()` output, so build one from a compact plaintext, then assert
      //     encode(decode(x)) == x byte-for-byte AND decode recovers the plaintext.
      @Test func roundTripIsByteIdentical() {
          let plaintext = #"{"PlayerInfo":{"m_Gold":999999999,"m_Bei":12345,"m_ChefFlame":67890},"SNSInfo":{"m_Follow_Count":42}}"#
          let sav = SaveCodec.encode(plaintext)
          #expect(SaveCodec.encode(SaveCodec.decode(sav)) == sav)
          #expect(SaveCodec.decode(sav) == plaintext)
      }

      // (c) CJK round-trip with ZERO U+FFFD, on a farm animal whose id is NOT
      //     11090001 (the exact case upstream silently corrupts).
      @Test func cjkRoundTripHasNoReplacementChar() {
          let plaintext = #"{"FarmAnimal":[{"FarmAnimalID":11090002,"Name":"白毛鸡"}]}"#
          let sav = SaveCodec.encode(plaintext)
          let decoded = SaveCodec.decode(sav)
          #expect(decoded == plaintext)
          #expect(!decoded.unicodeScalars.contains("\u{FFFD}"))
          #expect(SaveCodec.encode(decoded) == sav)
      }
  }
  ```

- [ ] **Step 2: Run the tests, expect RED.**
  Command: `swift test --filter SaveCodecTests`
  Expected: **FAIL** — compile error `cannot find 'SaveCodec' in scope` (type does not exist yet).

- [ ] **Step 3: Implement `SaveCodec` (GREEN).** Create `Sources/DaveSaveCore/SaveCodec.swift`. Pure, no I/O, deterministic; XOR over `[UInt16]` exactly per spec §5.3.
  ```swift
  import Foundation

  /// Char-level (UTF-16 code-unit) XOR codec mirroring the game's own algorithm.
  ///
  /// The on-disk `.sav` is the UTF-8 encoding of the per-code-unit-XOR'd JSON
  /// string. The key `"GameData"` is ASCII (all code units < 0x80) and cycles
  /// once per UTF-16 code unit. Both directions are pure and perform no I/O;
  /// by construction `encode(decode(x)) == x` byte-for-byte for any save the
  /// game itself produced (valid UTF-8), and CJK content survives losslessly.
  public enum SaveCodec {
      /// XOR key code units: `Array("GameData".utf16)`
      /// == [0x47, 0x61, 0x6D, 0x65, 0x44, 0x61, 0x74, 0x61].
      private static let key16: [UInt16] = Array("GameData".utf16)

      /// `.sav` bytes -> JSON text.
      public static func decode(_ data: Data) -> String {
          let encStr = String(decoding: data, as: UTF8.self)
          var units = Array(encStr.utf16)
          let keyCount = key16.count
          for i in units.indices {
              units[i] ^= key16[i % keyCount]
          }
          return String(decoding: units, as: UTF16.self)
      }

      /// JSON text -> `.sav` bytes.
      public static func encode(_ json: String) -> Data {
          var units = Array(json.utf16)
          let keyCount = key16.count
          for i in units.indices {
              units[i] ^= key16[i % keyCount]
          }
          return Data(String(decoding: units, as: UTF16.self).utf8)
      }
  }
  ```

- [ ] **Step 4: Run the tests, expect GREEN.**
  Command: `swift test --filter SaveCodecTests`
  Expected: **PASS** — all 5 tests pass (hand vector encode/decode, key code units, byte-identical round-trip, CJK no-`U+FFFD`).

- [ ] **Step 5: Commit.**
  ```sh
  git add Sources/DaveSaveCore/SaveCodec.swift Tests/DaveSaveCoreTests/SaveCodecTests.swift
  git commit -m "feat: add SaveCodec char-level UTF-16 XOR with round-trip and CJK tests"
  ```

---

### Task 3: OrderedJSON — lexeme-preserving parser + compact serializer

**Files:**
- Test: `Tests/DaveSaveCoreTests/OrderedJSONTests.swift` (create)
- Create: `Sources/DaveSaveCore/OrderedJSON.swift`

**Interfaces:**
- **Consumes:** the `DaveSaveCore` SwiftPM target + `DaveSaveCoreTests` test target scaffolded in Task 1 (swift-tools-version:6.0, `.macOS(.v14)`, Swift Testing). Pure Swift, no I/O, no Foundation. Does **not** depend on `SaveCodec` (Task 2).
- **Produces** (later tasks rely on these EXACT signatures — `SaveDocument` in Task 6+, and Task 4 below):
  - `public indirect enum OrderedJSON: Equatable { case object([Member]); case array([OrderedJSON]); case scalar(String) }`
  - `public struct Member: Equatable { public var keyLexeme: String; public var value: OrderedJSON; public init(keyLexeme: String, value: OrderedJSON); public var key: String { get } }`
  - `public enum JSONParseError: Error, Equatable { case unexpectedEnd; case unexpectedCharacter(Int); case invalidNumber(Int) }`
  - `public static func parse(_ text: String) throws -> OrderedJSON`
  - `public func serialized() -> String`

- [ ] **Step 1: Write the failing tests (round-trip byte-identity, big-int, non-ASCII, `Member.key` decode).**
  Create `Tests/DaveSaveCoreTests/OrderedJSONTests.swift`:
  ```swift
  import Testing
  import DaveSaveCore

  // Synthetic/anonymized fixtures only. Compact JSON (no whitespace), matching the
  // game's on-disk style: nested objects/arrays, a >2^53 big-int (LastUpdateTime-like),
  // CJK key+value, an escaped quote, negative/float/bool/null, and empty containers.
  private let compactFixture =
  #"{"PlayerInfo":{"m_Gold":999999999,"m_Bei":-5,"ratio":3.14,"flag":true,"none":null},"LastUpdateTime":639076164000175857,"名前":"白毛鸡","quote":"a\"b\\c","arr":[1,2,{"x":"y"}],"empty":{},"emptyArr":[]}"#

  @Suite struct OrderedJSONTests {

      @Test func noOpRoundTripIsByteIdentical() throws {
          let dom = try OrderedJSON.parse(compactFixture)
          #expect(dom.serialized() == compactFixture)
      }

      @Test func bigIntScalarIsPreservedVerbatim() throws {
          let dom = try OrderedJSON.parse(compactFixture)
          guard case .object(let members) = dom,
                let m = members.first(where: { $0.key == "LastUpdateTime" }) else {
              Issue.record("LastUpdateTime member missing"); return
          }
          #expect(m.value == .scalar("639076164000175857"))
      }

      @Test func scalarStringLexemesIncludeQuotesAndEscapes() throws {
          let dom = try OrderedJSON.parse(compactFixture)
          guard case .object(let members) = dom else { Issue.record("not object"); return }
          let name = members.first { $0.key == "名前" }
          #expect(name?.value == .scalar(#""白毛鸡""#))
          let quote = members.first { $0.key == "quote" }
          #expect(quote?.value == .scalar(#""a\"b\\c""#))   // verbatim, escapes intact
      }

      @Test func memberKeyDecodesQuotesAndEscapes() throws {
          let dom = try OrderedJSON.parse(#"{"ABC":1,"a\"b":2,"白":3}"#)
          guard case .object(let members) = dom else { Issue.record("not object"); return }
          #expect(members[0].keyLexeme == #""ABC""#) // verbatim lexeme keeps the escape
          #expect(members[0].key == "ABC")                // decoded: A -> A
          #expect(members[1].key == "a\"b")               // decoded: \" -> "
          #expect(members[2].key == "白")
      }

      @Test func emptyContainersRoundTrip() throws {
          #expect(try OrderedJSON.parse("{}").serialized() == "{}")
          #expect(try OrderedJSON.parse("[]").serialized() == "[]")
      }

      @Test func malformedInputsThrowTypedErrors() {
          #expect(throws: JSONParseError.self) { try OrderedJSON.parse("") }
          #expect(throws: JSONParseError.self) { try OrderedJSON.parse("{\"a\":}") }
          #expect(throws: JSONParseError.self) { try OrderedJSON.parse("{}x") } // trailing garbage
          #expect(throws: JSONParseError.self) { try OrderedJSON.parse("12.") } // bad number
      }
  }
  ```

- [ ] **Step 2: Run the tests (expect build failure — type does not exist yet).**
  Command: `swift test --filter OrderedJSONTests`
  Expected: **FAIL** (compile error: `OrderedJSON` / `Member` / `JSONParseError` undefined).

- [ ] **Step 3: Implement `OrderedJSON.swift` (types, recursive-descent parser, compact serializer, key decode).**
  Create `Sources/DaveSaveCore/OrderedJSON.swift`:
  ```swift
  // OrderedJSON — lexeme-preserving JSON DOM.
  // Pure Swift, no Foundation. Every untouched token re-emits its verbatim source
  // lexeme, so decode -> parse -> serialize with zero edits is byte-identical for
  // compact input (the game writes compact JSON). Numbers/bool/null are stored as
  // their raw source text; strings keep their surrounding quotes and escapes.

  public indirect enum OrderedJSON: Equatable {
      case object([Member])
      case array([OrderedJSON])
      /// VERBATIM source lexeme of the value token:
      /// numbers/bool/null as-is ("999999999","true","null");
      /// strings INCLUDING surrounding quotes & escapes (#""abc""#).
      case scalar(String)
  }

  public struct Member: Equatable {
      /// Verbatim key token INCLUDING quotes, e.g. #""m_Gold""#.
      public var keyLexeme: String
      public var value: OrderedJSON

      public init(keyLexeme: String, value: OrderedJSON) {
          self.keyLexeme = keyLexeme
          self.value = value
      }

      /// Decoded key: surrounding quotes stripped + JSON escapes resolved.
      public var key: String {
          OrderedJSON.decodeStringLexeme(keyLexeme)
      }
  }

  public enum JSONParseError: Error, Equatable {
      case unexpectedEnd
      case unexpectedCharacter(Int)
      case invalidNumber(Int)
  }

  // MARK: - Parsing

  public extension OrderedJSON {

      /// Recursive-descent parser that captures verbatim lexemes for scalars and keys.
      /// Skips insignificant whitespace between tokens (a no-op for compact input).
      static func parse(_ text: String) throws -> OrderedJSON {
          var parser = Parser(text)
          let value = try parser.parseValue()
          parser.skipWhitespace()
          guard parser.isAtEnd else {
              throw JSONParseError.unexpectedCharacter(parser.position)
          }
          return value
      }

      /// Compact serialization: no whitespace, lexemes emitted verbatim.
      func serialized() -> String {
          switch self {
          case .scalar(let lexeme):
              return lexeme
          case .array(let elements):
              var s = "["
              for (i, element) in elements.enumerated() {
                  if i > 0 { s += "," }
                  s += element.serialized()
              }
              s += "]"
              return s
          case .object(let members):
              var s = "{"
              for (i, member) in members.enumerated() {
                  if i > 0 { s += "," }
                  s += member.keyLexeme
                  s += ":"
                  s += member.value.serialized()
              }
              s += "}"
              return s
          }
      }
  }

  // MARK: - Key/string lexeme decoding

  extension OrderedJSON {

      /// Decode a verbatim JSON string lexeme (with surrounding quotes) into its value:
      /// strips the quotes and resolves \" \\ \/ \n \t \r \b \f and \uXXXX
      /// (including UTF-16 surrogate pairs). Returns the input unchanged if it is not a
      /// quoted string (defensive; never the case for valid keys).
      static func decodeStringLexeme(_ lexeme: String) -> String {
          let chars = Array(lexeme)
          guard chars.count >= 2, chars.first == "\"", chars.last == "\"" else {
              return lexeme
          }
          var result = ""
          var i = 1
          let end = chars.count - 1   // index of the closing quote

          func parseHex4(_ start: Int) -> UInt32? {
              guard start + 4 <= end else { return nil }
              var value: UInt32 = 0
              for k in start..<(start + 4) {
                  guard let d = chars[k].hexDigitValue else { return nil }
                  value = value * 16 + UInt32(d)
              }
              return value
          }

          while i < end {
              let c = chars[i]
              guard c == "\\", i + 1 < end else {
                  result.append(c)
                  i += 1
                  continue
              }
              let esc = chars[i + 1]
              switch esc {
              case "\"": result.append("\""); i += 2
              case "\\": result.append("\\"); i += 2
              case "/":  result.append("/");  i += 2
              case "n":  result.append("\n"); i += 2
              case "t":  result.append("\t"); i += 2
              case "r":  result.append("\r"); i += 2
              case "b":  result.append("\u{08}"); i += 2
              case "f":  result.append("\u{0C}"); i += 2
              case "u":
                  guard let hi = parseHex4(i + 2) else {
                      // Malformed \u — keep the escape char literally and move on.
                      result.append(esc); i += 2; continue
                  }
                  if hi >= 0xD800 && hi <= 0xDBFF {
                      // High surrogate: try to pair with a following \uXXXX low surrogate.
                      if i + 6 < end, chars[i + 6] == "\\", chars[i + 7] == "u",
                         let lo = parseHex4(i + 8), lo >= 0xDC00, lo <= 0xDFFF {
                          let combined = 0x10000 + (hi - 0xD800) * 0x400 + (lo - 0xDC00)
                          if let scalar = Unicode.Scalar(combined) {
                              result.unicodeScalars.append(scalar)
                          }
                          i += 12
                      } else {
                          if let scalar = Unicode.Scalar(hi) {
                              result.unicodeScalars.append(scalar)
                          }
                          i += 6
                      }
                  } else if let scalar = Unicode.Scalar(hi) {
                      result.unicodeScalars.append(scalar)
                      i += 6
                  } else {
                      // Lone low surrogate / invalid scalar: drop it.
                      i += 6
                  }
              default:
                  result.append(esc); i += 2
              }
          }
          return result
      }
  }

  // MARK: - Recursive-descent parser

  private struct Parser {
      let chars: [Character]
      var pos: Int = 0

      init(_ text: String) { chars = Array(text) }

      var isAtEnd: Bool { pos >= chars.count }
      var position: Int { pos }

      mutating func skipWhitespace() {
          while pos < chars.count {
              switch chars[pos] {
              case " ", "\t", "\n", "\r": pos += 1
              default: return
              }
          }
      }

      mutating func parseValue() throws -> OrderedJSON {
          skipWhitespace()
          guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
          let c = chars[pos]
          switch c {
          case "{": return try parseObject()
          case "[": return try parseArray()
          case "\"": return .scalar(try parseStringLexeme())
          case "t": return .scalar(try parseLiteral("true"))
          case "f": return .scalar(try parseLiteral("false"))
          case "n": return .scalar(try parseLiteral("null"))
          case "-": return .scalar(try parseNumber())
          default:
              if ("0"..."9").contains(c) { return .scalar(try parseNumber()) }
              throw JSONParseError.unexpectedCharacter(pos)
          }
      }

      mutating func parseObject() throws -> OrderedJSON {
          pos += 1 // consume '{'
          var members: [Member] = []
          skipWhitespace()
          if pos < chars.count, chars[pos] == "}" {
              pos += 1
              return .object(members)
          }
          while true {
              skipWhitespace()
              guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
              guard chars[pos] == "\"" else { throw JSONParseError.unexpectedCharacter(pos) }
              let keyLexeme = try parseStringLexeme()
              skipWhitespace()
              guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
              guard chars[pos] == ":" else { throw JSONParseError.unexpectedCharacter(pos) }
              pos += 1 // consume ':'
              let value = try parseValue()
              members.append(Member(keyLexeme: keyLexeme, value: value))
              skipWhitespace()
              guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
              switch chars[pos] {
              case ",": pos += 1
              case "}": pos += 1; return .object(members)
              default: throw JSONParseError.unexpectedCharacter(pos)
              }
          }
      }

      mutating func parseArray() throws -> OrderedJSON {
          pos += 1 // consume '['
          var elements: [OrderedJSON] = []
          skipWhitespace()
          if pos < chars.count, chars[pos] == "]" {
              pos += 1
              return .array(elements)
          }
          while true {
              let value = try parseValue()
              elements.append(value)
              skipWhitespace()
              guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
              switch chars[pos] {
              case ",": pos += 1
              case "]": pos += 1; return .array(elements)
              default: throw JSONParseError.unexpectedCharacter(pos)
              }
          }
      }

      /// Captures a string from its opening quote to its closing quote inclusive,
      /// honoring backslash escapes so an escaped quote does not terminate it.
      mutating func parseStringLexeme() throws -> String {
          let start = pos
          pos += 1 // consume opening '"'
          while pos < chars.count {
              let c = chars[pos]
              if c == "\\" {
                  pos += 1
                  guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
                  pos += 1 // skip the escaped char (its tail, e.g. \u hex, is read as normal chars)
              } else if c == "\"" {
                  pos += 1 // consume closing '"'
                  return String(chars[start..<pos])
              } else {
                  pos += 1
              }
          }
          throw JSONParseError.unexpectedEnd
      }

      /// Captures a verbatim JSON number lexeme; throws invalidNumber on malformed input.
      mutating func parseNumber() throws -> String {
          let start = pos
          if pos < chars.count, chars[pos] == "-" { pos += 1 }
          guard pos < chars.count, ("0"..."9").contains(chars[pos]) else {
              throw JSONParseError.invalidNumber(start)
          }
          if chars[pos] == "0" {
              pos += 1
          } else {
              while pos < chars.count, ("0"..."9").contains(chars[pos]) { pos += 1 }
          }
          if pos < chars.count, chars[pos] == "." {
              pos += 1
              guard pos < chars.count, ("0"..."9").contains(chars[pos]) else {
                  throw JSONParseError.invalidNumber(start)
              }
              while pos < chars.count, ("0"..."9").contains(chars[pos]) { pos += 1 }
          }
          if pos < chars.count, chars[pos] == "e" || chars[pos] == "E" {
              pos += 1
              if pos < chars.count, chars[pos] == "+" || chars[pos] == "-" { pos += 1 }
              guard pos < chars.count, ("0"..."9").contains(chars[pos]) else {
                  throw JSONParseError.invalidNumber(start)
              }
              while pos < chars.count, ("0"..."9").contains(chars[pos]) { pos += 1 }
          }
          return String(chars[start..<pos])
      }

      mutating func parseLiteral(_ literal: String) throws -> String {
          let lit = Array(literal)
          guard pos + lit.count <= chars.count else { throw JSONParseError.unexpectedCharacter(pos) }
          for k in 0..<lit.count where chars[pos + k] != lit[k] {
              throw JSONParseError.unexpectedCharacter(pos)
          }
          pos += lit.count
          return literal
      }
  }
  ```

- [ ] **Step 4: Run the tests (expect green).**
  Command: `swift test --filter OrderedJSONTests`
  Expected: **PASS** (round-trip byte-identical incl. big-int + CJK + escaped quote; `Member.key` decodes `A`/`\"`/CJK; malformed inputs throw typed errors).

- [ ] **Step 5: Commit.**
  ```bash
  git add Sources/DaveSaveCore/OrderedJSON.swift Tests/DaveSaveCoreTests/OrderedJSONTests.swift
  git commit -m "feat: add lexeme-preserving OrderedJSON parser and compact serializer"
  ```

---

### Task 4: OrderedJSON path access & mutation — `value(at:)`, `setScalar(at:lexeme:)`, `setMember(at:member:)`

**Files:**
- Test: `Tests/DaveSaveCoreTests/OrderedJSONPathTests.swift` (create)
- Create: `Sources/DaveSaveCore/OrderedJSONPath.swift`

**Interfaces:**
- **Consumes** (from Task 3): `OrderedJSON.parse(_:)`, `OrderedJSON.serialized()`, `OrderedJSON` cases `.object/.array/.scalar`, `Member(keyLexeme:value:)`, `Member.key`.
- **Produces** (the editing primitives `SaveDocument` (Task 6+) uses for `setGold`/`setBei`/`setArtisansFlame`/`setFollowerCount` and Max-All ingredient injection):
  - `func value(at path: [String]) -> OrderedJSON?` — walk object members by decoded key.
  - `mutating func setScalar(at path: [String], lexeme: String) -> Bool` — replace a scalar leaf; `false` if the path is missing or the target is not a scalar.
  - `mutating func setMember(at path: [String], member: Member) -> Bool` — in the object reached by `path`, replace the member whose decoded key matches `member.key` **in place**, else append it at the end; `false` if `path` does not reach an object.

- [ ] **Step 1: Write the failing tests (read nested path; setScalar isolates one lexeme; setMember replaces-in-place / appends-ordered).**
  Create `Tests/DaveSaveCoreTests/OrderedJSONPathTests.swift`:
  ```swift
  import Testing
  import DaveSaveCore

  // Synthetic fixture mirroring the real editable paths (PlayerInfo.*, Ingredients.<id>.count),
  // including a non-11090001 farm-animal ingredient id to match the project's fixture policy.
  private let base =
  #"{"PlayerInfo":{"m_Gold":100,"m_Bei":200},"Ingredients":{"14090007":{"count":5}}}"#

  @Suite struct OrderedJSONPathTests {

      @Test func readsNestedScalarByDecodedKeyPath() throws {
          let dom = try OrderedJSON.parse(base)
          #expect(dom.value(at: ["PlayerInfo", "m_Gold"]) == .scalar("100"))
          #expect(dom.value(at: ["Ingredients", "14090007", "count"]) == .scalar("5"))
          #expect(dom.value(at: []) == dom)                       // empty path == self
          #expect(dom.value(at: ["PlayerInfo", "missing"]) == nil) // missing key
          #expect(dom.value(at: ["PlayerInfo", "m_Gold", "x"]) == nil) // descend into scalar
      }

      @Test func setScalarChangesOnlyTheTargetLexeme() throws {
          var dom = try OrderedJSON.parse(base)
          #expect(dom.setScalar(at: ["PlayerInfo", "m_Gold"], lexeme: "999999999") == true)
          #expect(dom.serialized() ==
              #"{"PlayerInfo":{"m_Gold":999999999,"m_Bei":200},"Ingredients":{"14090007":{"count":5}}}"#)
      }

      @Test func setScalarRejectsMissingOrNonScalarTargets() throws {
          var dom = try OrderedJSON.parse(base)
          #expect(dom.setScalar(at: ["PlayerInfo", "missing"], lexeme: "1") == false)
          #expect(dom.setScalar(at: ["PlayerInfo"], lexeme: "1") == false) // target is an object
          #expect(dom.serialized() == base)                                // unchanged on failure
      }

      @Test func setMemberAppendsNewMemberInOrder() throws {
          var dom = try OrderedJSON.parse(base)
          let injected = Member(keyLexeme: #""14010001""#, value: try OrderedJSON.parse(#"{"count":66}"#))
          #expect(dom.setMember(at: ["Ingredients"], member: injected) == true)
          #expect(dom.serialized() ==
              #"{"PlayerInfo":{"m_Gold":100,"m_Bei":200},"Ingredients":{"14090007":{"count":5},"14010001":{"count":66}}}"#)
      }

      @Test func setMemberReplacesExistingMemberInPlace() throws {
          var dom = try OrderedJSON.parse(base)
          let replacement = Member(keyLexeme: #""14090007""#, value: try OrderedJSON.parse(#"{"count":6666}"#))
          #expect(dom.setMember(at: ["Ingredients"], member: replacement) == true)
          #expect(dom.serialized() ==
              #"{"PlayerInfo":{"m_Gold":100,"m_Bei":200},"Ingredients":{"14090007":{"count":6666}}}"#)
      }

      @Test func setMemberFailsWhenPathIsNotAnObject() throws {
          var dom = try OrderedJSON.parse(base)
          let m = Member(keyLexeme: #""z""#, value: .scalar("1"))
          #expect(dom.setMember(at: ["PlayerInfo", "m_Gold"], member: m) == false) // path ends at scalar
          #expect(dom.setMember(at: ["nope"], member: m) == false)                 // missing path
          #expect(dom.serialized() == base)
      }
  }
  ```

- [ ] **Step 2: Run the tests (expect build failure — methods do not exist yet).**
  Command: `swift test --filter OrderedJSONPathTests`
  Expected: **FAIL** (compile error: `value(at:)` / `setScalar(at:lexeme:)` / `setMember(at:member:)` undefined).

- [ ] **Step 3: Implement `OrderedJSONPath.swift` (path read + scalar/member mutation, copy-mutate-writeback recursion).**
  Create `Sources/DaveSaveCore/OrderedJSONPath.swift`:
  ```swift
  // Path access & mutation over OrderedJSON. Paths are arrays of DECODED keys, walked
  // through object members (see Member.key). Mutation uses value-type copy-mutate-
  // writeback recursion so only the targeted leaf/member is touched — every other
  // token keeps its verbatim lexeme, preserving byte-exact serialization elsewhere.

  public extension OrderedJSON {

      /// Walk object members by decoded key. Empty path returns self. Returns nil if any
      /// step is not an object or the key is absent.
      func value(at path: [String]) -> OrderedJSON? {
          var current = self
          for key in path {
              guard case .object(let members) = current,
                    let member = members.first(where: { $0.key == key }) else {
                  return nil
              }
              current = member.value
          }
          return current
      }

      /// Replace a scalar leaf, keeping its position and every sibling lexeme intact.
      /// Returns false if the path is missing or the target value is not a scalar.
      @discardableResult
      mutating func setScalar(at path: [String], lexeme: String) -> Bool {
          guard let first = path.first else {
              // Empty path: only valid when self is itself a scalar leaf.
              if case .scalar = self { self = .scalar(lexeme); return true }
              return false
          }
          guard case .object(var members) = self,
                let idx = members.firstIndex(where: { $0.key == first }) else {
              return false
          }
          if path.count == 1 {
              guard case .scalar = members[idx].value else { return false }
              members[idx].value = .scalar(lexeme)
              self = .object(members)
              return true
          }
          var child = members[idx].value
          guard child.setScalar(at: Array(path.dropFirst()), lexeme: lexeme) else { return false }
          members[idx].value = child
          self = .object(members)
          return true
      }

      /// In the object reached by `path`, replace the member whose decoded key matches
      /// `member.key` in place, else append it at the end (ordered). Empty path targets
      /// self. Returns false if `path` does not reach an object.
      @discardableResult
      mutating func setMember(at path: [String], member: Member) -> Bool {
          guard let first = path.first else {
              guard case .object(var members) = self else { return false }
              if let idx = members.firstIndex(where: { $0.key == member.key }) {
                  members[idx] = member
              } else {
                  members.append(member)
              }
              self = .object(members)
              return true
          }
          guard case .object(var members) = self,
                let idx = members.firstIndex(where: { $0.key == first }) else {
              return false
          }
          var child = members[idx].value
          guard child.setMember(at: Array(path.dropFirst()), member: member) else { return false }
          members[idx].value = child
          self = .object(members)
          return true
      }
  }
  ```

- [ ] **Step 4: Run the tests (expect green).**
  Command: `swift test --filter OrderedJSONPathTests`
  Expected: **PASS** (nested read by decoded key; `setScalar` flips exactly one lexeme and leaves the rest byte-identical, rejects missing/non-scalar; `setMember` appends ordered and replaces in place, fails on non-object path).

- [ ] **Step 5: Run the full OrderedJSON suite together (no regressions across Tasks 3 & 4).**
  Command: `swift test --filter 'OrderedJSON.*Tests'`
  Expected: **PASS** (both `OrderedJSONTests` and `OrderedJSONPathTests`).

- [ ] **Step 6: Commit.**
  ```bash
  git add Sources/DaveSaveCore/OrderedJSONPath.swift Tests/DaveSaveCoreTests/OrderedJSONPathTests.swift
  git commit -m "feat: add OrderedJSON path read and scalar/member mutation"
  ```

---

### Task 5: SaveDocument — load/encode, currency getters/setters, pendingChanges

**Files:**
- Create: `Sources/DaveSaveCore/SaveDocument.swift`
- Test: `Tests/DaveSaveCoreTests/SaveDocumentTests.swift`

**Interfaces:**
- **Consumes** (from earlier tasks):
  - Task 2 — `SaveCodec.decode(_ data: Data) -> String`, `SaveCodec.encode(_ json: String) -> Data`
  - Tasks 3–4 — `OrderedJSON.parse(_ text: String) throws -> OrderedJSON`, `OrderedJSON.serialized() -> String`, `OrderedJSON.value(at path: [String]) -> OrderedJSON?`, `OrderedJSON.setScalar(at path: [String], lexeme: String) -> Bool`, and `enum JSONParseError: Error, Equatable`.
- **Produces** (later tasks rely on these exact signatures):
  - `public struct FieldChange: Equatable { public let path: String; public let oldValue: String; public let newValue: String }`
  - `public struct SaveDocument` with `public static func load(_ data: Data) throws -> SaveDocument`, `public func encoded() -> Data`, getters `gold/bei/artisansFlame/followerCount: Int64`, mutating setters `setGold/setBei/setArtisansFlame/setFollowerCount(_ v: Int64)`, and `public func pendingChanges() -> [FieldChange]`.
  - Module-internal stored property `var root: OrderedJSON`, the immutable snapshot `let originalRoot: OrderedJSON`, plus internal helpers `static func scalarLexeme(in:at:)`, `static let currencyClamp/goldPath/beiPath/flamePath/followerPath`. The later ingredient-ops task adds `maxOwnedIngredients(using:)` / `maxAllIngredients(using:)` as a same-module `extension SaveDocument` mutating `root` via `setScalar`/`setMember` — it depends on `root` and these helpers being module-internal.

---

- [ ] **Step 1: Add the failing test suite (synthetic fixtures only — no real save).**

  Create `Tests/DaveSaveCoreTests/SaveDocumentTests.swift`:

  ```swift
  import Foundation
  import Testing
  @testable import DaveSaveCore

  @Suite("SaveDocument")
  struct SaveDocumentTests {

      /// Compact, synthetic save JSON (never a real user's save).
      static let fixtureJSON =
          #"{"PlayerInfo":{"m_Gold":12345,"m_Bei":678,"m_ChefFlame":90},"SNSInfo":{"m_Follow_Count":42}}"#

      /// Build `.sav` bytes for the fixture using the Task-2 codec.
      static func fixtureData() -> Data {
          SaveCodec.encode(fixtureJSON)
      }

      @Test("load decodes + parses; currency getters read the lexemes")
      func loadReadsCurrencies() throws {
          let doc = try SaveDocument.load(Self.fixtureData())
          #expect(doc.gold == 12345)
          #expect(doc.bei == 678)
          #expect(doc.artisansFlame == 90)
          #expect(doc.followerCount == 42)
      }

      @Test("missing currency path reads as 0")
      func missingFieldIsZero() throws {
          let doc = try SaveDocument.load(SaveCodec.encode(#"{"PlayerInfo":{}}"#))
          #expect(doc.gold == 0)
          #expect(doc.followerCount == 0)
      }

      @Test("invalid JSON throws JSONParseError")
      func invalidJSONThrows() {
          let data = SaveCodec.encode("{not json")
          #expect(throws: JSONParseError.self) {
              _ = try SaveDocument.load(data)
          }
      }

      @Test("setGold to max sets value and survives an encode round-trip")
      func setGoldRoundTrips() throws {
          var doc = try SaveDocument.load(Self.fixtureData())
          doc.setGold(999_999_999)
          #expect(doc.gold == 999_999_999)

          let reloaded = try SaveDocument.load(doc.encoded())
          #expect(reloaded.gold == 999_999_999)
          // Untouched fields are preserved through the round-trip.
          #expect(reloaded.bei == 678)
          #expect(reloaded.artisansFlame == 90)
          #expect(reloaded.followerCount == 42)
      }

      @Test("setGold clamps above the currency cap")
      func setGoldClamps() throws {
          var doc = try SaveDocument.load(Self.fixtureData())
          doc.setGold(10_000_000_000)
          #expect(doc.gold == 999_999_999)
      }

      @Test("setBei and setArtisansFlame clamp to the cap")
      func beiAndFlameClamp() throws {
          var doc = try SaveDocument.load(Self.fixtureData())
          doc.setBei(10_000_000_000)
          doc.setArtisansFlame(10_000_000_000)
          #expect(doc.bei == 999_999_999)
          #expect(doc.artisansFlame == 999_999_999)
      }

      @Test("setFollowerCount is NOT clamped")
      func followerNotClamped() throws {
          var doc = try SaveDocument.load(Self.fixtureData())
          doc.setFollowerCount(10_000_000_000)
          #expect(doc.followerCount == 10_000_000_000)
          let reloaded = try SaveDocument.load(doc.encoded())
          #expect(reloaded.followerCount == 10_000_000_000)
      }

      @Test("pendingChanges reports gold old -> new and nothing else")
      func pendingChangesReportsGold() throws {
          var doc = try SaveDocument.load(Self.fixtureData())
          #expect(doc.pendingChanges().isEmpty)

          doc.setGold(999_999_999)
          let changes = doc.pendingChanges()
          #expect(changes == [FieldChange(path: "PlayerInfo.m_Gold",
                                          oldValue: "12345",
                                          newValue: "999999999")])
      }
  }
  ```

- [ ] **Step 2: Run the suite (expect red — `SaveDocument`/`FieldChange` do not exist yet).**

  Command: `swift test --filter SaveDocumentTests`
  Expected: FAIL (compile error: cannot find `SaveDocument` / `FieldChange` in scope).

- [ ] **Step 3: Implement `SaveDocument` (load = decode→parse; getters Int64 the scalar lexeme, default 0; setters clamp gold/bei/flame to 999_999_999, follower unclamped; encoded = serialized→encode; pendingChanges diffs over the 4 currency paths).**

  Create `Sources/DaveSaveCore/SaveDocument.swift`:

  ```swift
  import Foundation

  /// A single previewable edit: `path` is the dotted display path, `oldValue`
  /// and `newValue` are the verbatim scalar lexemes before/after editing.
  public struct FieldChange: Equatable {
      public let path: String
      public let oldValue: String
      public let newValue: String

      public init(path: String, oldValue: String, newValue: String) {
          self.path = path
          self.oldValue = oldValue
          self.newValue = newValue
      }
  }

  /// Load / edit / write API over a parsed Dave the Diver save.
  public struct SaveDocument {

      // MARK: Stored state

      /// The live, editable document. Mutated by the currency setters here and,
      /// in a later task, by the ingredient Max-Own / Max-All operations.
      var root: OrderedJSON

      /// Immutable snapshot captured at load time, used by `pendingChanges()`.
      let originalRoot: OrderedJSON

      private init(root: OrderedJSON) {
          self.root = root
          self.originalRoot = root
      }

      // MARK: Constants — editable paths & clamp

      static let currencyClamp: Int64 = 999_999_999

      static let goldPath:     [String] = ["PlayerInfo", "m_Gold"]
      static let beiPath:      [String] = ["PlayerInfo", "m_Bei"]
      static let flamePath:    [String] = ["PlayerInfo", "m_ChefFlame"]
      static let followerPath: [String] = ["SNSInfo", "m_Follow_Count"]

      /// Dotted display path paired with its lookup path, in preview order.
      static let currencyPaths: [(dotted: String, path: [String])] = [
          ("PlayerInfo.m_Gold",      goldPath),
          ("PlayerInfo.m_Bei",       beiPath),
          ("PlayerInfo.m_ChefFlame", flamePath),
          ("SNSInfo.m_Follow_Count", followerPath),
      ]

      // MARK: Load / encode

      /// Decode `.sav` bytes (Task-2 codec) and parse to the lexeme-preserving
      /// DOM. Throws `JSONParseError` when the decoded text is not valid JSON.
      public static func load(_ data: Data) throws -> SaveDocument {
          let json = SaveCodec.decode(data)
          let parsed = try OrderedJSON.parse(json)
          return SaveDocument(root: parsed)
      }

      /// Serialize the (possibly edited) DOM compactly and re-encode to bytes.
      public func encoded() -> Data {
          SaveCodec.encode(root.serialized())
      }

      // MARK: Scalar helpers

      /// Verbatim scalar lexeme at `path` in `json`, or `nil` if the path is
      /// missing or the leaf is not a scalar.
      static func scalarLexeme(in json: OrderedJSON, at path: [String]) -> String? {
          guard case .scalar(let lexeme)? = json.value(at: path) else { return nil }
          return lexeme
      }

      /// Int64 reading of the scalar lexeme at `path`, defaulting to 0 when the
      /// path is missing, non-scalar, or not an integer lexeme.
      private func intValue(at path: [String]) -> Int64 {
          guard let lexeme = Self.scalarLexeme(in: root, at: path) else { return 0 }
          return Int64(lexeme) ?? 0
      }

      @discardableResult
      private mutating func setInt(_ value: Int64, at path: [String]) -> Bool {
          root.setScalar(at: path, lexeme: String(value))
      }

      // MARK: Currency getters

      public var gold: Int64          { intValue(at: Self.goldPath) }
      public var bei: Int64           { intValue(at: Self.beiPath) }
      public var artisansFlame: Int64 { intValue(at: Self.flamePath) }
      public var followerCount: Int64 { intValue(at: Self.followerPath) }

      // MARK: Currency setters

      public mutating func setGold(_ v: Int64) {
          setInt(min(v, Self.currencyClamp), at: Self.goldPath)
      }

      public mutating func setBei(_ v: Int64) {
          setInt(min(v, Self.currencyClamp), at: Self.beiPath)
      }

      public mutating func setArtisansFlame(_ v: Int64) {
          setInt(min(v, Self.currencyClamp), at: Self.flamePath)
      }

      public mutating func setFollowerCount(_ v: Int64) {
          setInt(v, at: Self.followerPath)   // unclamped (matches upstream)
      }

      // MARK: Pending-change diff (preview)

      /// Diff the current document against the load-time snapshot over the four
      /// known editable currency paths. Reports `old -> new` verbatim lexemes.
      public func pendingChanges() -> [FieldChange] {
          var changes: [FieldChange] = []
          for entry in Self.currencyPaths {
              let oldValue = Self.scalarLexeme(in: originalRoot, at: entry.path) ?? ""
              let newValue = Self.scalarLexeme(in: root,         at: entry.path) ?? ""
              if oldValue != newValue {
                  changes.append(FieldChange(path: entry.dotted,
                                             oldValue: oldValue,
                                             newValue: newValue))
              }
          }
          return changes
      }
  }
  ```

- [ ] **Step 4: Re-run the suite (expect green).**

  Command: `swift test --filter SaveDocumentTests`
  Expected: PASS (all 8 tests pass).

- [ ] **Step 5: Commit.**

  Command:
  ```
  git add Sources/DaveSaveCore/SaveDocument.swift Tests/DaveSaveCoreTests/SaveDocumentTests.swift
  git commit -m "feat(core): SaveDocument load/encode, currency getters/setters, pendingChanges"
  ```

---

### Task 6: ReferenceDB (read-only SQLite over the ingredient/items reference data)

**Files:**
- Create `Sources/DaveSaveCore/ReferenceDB.swift`
- Create `Tests/DaveSaveCoreTests/TestSupport.swift` (shared SQLite fixture builder, also consumed by Task 7)
- Test `Tests/DaveSaveCoreTests/ReferenceDBTests.swift`

**Interfaces:**
- **Consumes:** Package target `DaveSaveCore` (Task 1) links the macOS system SQLite via `import SQLite3` and ships `reference.sqlite` as a `Bundle.module` resource (`.process("Resources")`), so `Bundle.module` exists and `bundled()` compiles. No sibling-source dependencies.
- **Produces (Task 7 relies on these exact signatures):**
  ```swift
  public struct IngredientRow: Equatable {
      public let id: Int; public let parentID: Int; public let maxCount: Int; public let dlcType: Int
      public init(id: Int, parentID: Int, maxCount: Int, dlcType: Int)
  }
  public final class ReferenceDB {
      public init(url: URL) throws
      public static func bundled() throws -> ReferenceDB
      public func maxCount(itemDataID: Int) -> Int?
      public func allIngredients() -> [IngredientRow]
  }
  ```
  Schema (from `embedded_sql.h`): `Items(TID PK AUTOINCREMENT, …, ItemDataID, …, MaxCount, …, DLCType)`; `Ingredients(TID PK, Type)`. The join is `Ingredients.TID = Items.ItemDataID`, and the returned `parentID` is the matched `Items.TID` (primary key), **not** the `ItemDataID`. Verified real rows: `ItemDataID 1020201 → MaxCount 9999`; join row `(I.TID 1020201, T.TID 1010201, 9999, DLCType 1)`; full DB has 563 Items / 305 Ingredients.

- [ ] **Step 1: Write the failing test fixture builder `TestSupport.swift`.** Creates a tiny read-write SQLite on disk (so `ReferenceDB`'s READONLY open has a file to read), mirroring the real schema columns we query, with rows hand-picked to exercise every tier and DLC branch.
  ```swift
  import Foundation
  import SQLite3

  enum TestSupportError: Error { case cannotCreate(Int32); case exec(String) }

  /// Builds a minimal `reference.sqlite`-shaped database at `url`.
  /// Rows mirror real game data so they double as documentation:
  ///   ItemDataID 1020201 -> MaxCount 9999 (tier 6666), DLCType 1 (Sea People)
  ///   ItemDataID 1021011 -> MaxCount 99   (tier 66),   DLCType 0 (base)
  ///   ItemDataID 1025901 -> MaxCount 1    (tier skip), DLCType 0 (base)
  ///   ItemDataID 1027019 -> MaxCount 9999 (tier 6666), DLCType 5 (Godzilla)
  /// `Items.TID` is the primary key returned as `parentID` by the join.
  func makeTinyReferenceDB(at url: URL) throws {
      try? FileManager.default.removeItem(at: url)
      var handle: OpaquePointer?
      let rc = sqlite3_open(url.path, &handle)
      guard rc == SQLITE_OK, let handle else {
          sqlite3_close(handle)
          throw TestSupportError.cannotCreate(rc)
      }
      defer { sqlite3_close(handle) }
      let sql = """
      CREATE TABLE Items (
          TID INTEGER PRIMARY KEY,
          ItemDataID INTEGER NOT NULL,
          MaxCount INTEGER NOT NULL,
          DLCType INTEGER NOT NULL
      );
      CREATE TABLE Ingredients (
          TID INTEGER PRIMARY KEY,
          Type INTEGER NOT NULL
      );
      INSERT INTO Items VALUES (1010201, 1020201, 9999, 1);
      INSERT INTO Items VALUES (1011701, 1021011, 99,   0);
      INSERT INTO Items VALUES (1018901, 1025901, 1,    0);
      INSERT INTO Items VALUES (1017019, 1027019, 9999, 5);
      INSERT INTO Ingredients VALUES (1020201, 0);
      INSERT INTO Ingredients VALUES (1021011, 0);
      INSERT INTO Ingredients VALUES (1025901, 0);
      INSERT INTO Ingredients VALUES (1027019, 0);
      """
      var errMsg: UnsafeMutablePointer<CChar>?
      guard sqlite3_exec(handle, sql, nil, nil, &errMsg) == SQLITE_OK else {
          let msg = errMsg.map { String(cString: $0) } ?? "unknown"
          sqlite3_free(errMsg)
          throw TestSupportError.exec(msg)
      }
  }
  ```

- [ ] **Step 2: Write the failing tests `ReferenceDBTests.swift`.**
  ```swift
  import Foundation
  import Testing
  @testable import DaveSaveCore

  @Suite struct ReferenceDBTests {
      private func freshDB() throws -> (ReferenceDB, URL) {
          let url = FileManager.default.temporaryDirectory
              .appendingPathComponent("ref-\(UUID().uuidString).sqlite")
          try makeTinyReferenceDB(at: url)
          return (try ReferenceDB(url: url), url)
      }

      @Test func maxCountReturnsKnownRow() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          #expect(db.maxCount(itemDataID: 1020201) == 9999)
          #expect(db.maxCount(itemDataID: 1021011) == 99)
          #expect(db.maxCount(itemDataID: 1025901) == 1)
      }

      @Test func maxCountReturnsNilForMissingItem() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          #expect(db.maxCount(itemDataID: 99_999_999) == nil)
      }

      @Test func allIngredientsJoinsItemsByItemDataID() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          let rows = db.allIngredients()
          #expect(rows.count == 4)
          // parentID is the matched Items.TID (primary key), not the ItemDataID.
          #expect(rows.contains(IngredientRow(id: 1020201, parentID: 1010201, maxCount: 9999, dlcType: 1)))
          #expect(rows.contains(IngredientRow(id: 1021011, parentID: 1011701, maxCount: 99,   dlcType: 0)))
          #expect(rows.contains(IngredientRow(id: 1025901, parentID: 1018901, maxCount: 1,    dlcType: 0)))
          #expect(rows.contains(IngredientRow(id: 1027019, parentID: 1017019, maxCount: 9999, dlcType: 5)))
      }

      @Test func initThrowsForMissingFile() {
          let url = FileManager.default.temporaryDirectory
              .appendingPathComponent("missing-\(UUID().uuidString).sqlite")
          #expect(throws: (any Error).self) { _ = try ReferenceDB(url: url) }
      }
  }
  ```

- [ ] **Step 3: Run the tests — RED (no `ReferenceDB` yet).**
  Command: `swift test --filter ReferenceDBTests`
  Expected: FAIL (compile error: cannot find `ReferenceDB` / `IngredientRow` in scope).

- [ ] **Step 4: Implement `ReferenceDB.swift` to pass.** READONLY open via `sqlite3_open_v2`; prepared statements; `Int64` binds/columns to avoid 32-bit overflow surprises; deterministic finalize via `defer`.
  ```swift
  import Foundation
  import SQLite3

  public struct IngredientRow: Equatable {
      public let id: Int
      public let parentID: Int
      public let maxCount: Int
      public let dlcType: Int
      public init(id: Int, parentID: Int, maxCount: Int, dlcType: Int) {
          self.id = id
          self.parentID = parentID
          self.maxCount = maxCount
          self.dlcType = dlcType
      }
  }

  public enum ReferenceDBError: Error, Equatable {
      case cannotOpen(code: Int32)
      case missingBundleResource
  }

  public final class ReferenceDB {
      private let db: OpaquePointer

      /// Opens the database read-only (`SQLITE_OPEN_READONLY`); throws if the file
      /// is missing or cannot be opened.
      public init(url: URL) throws {
          var handle: OpaquePointer?
          let rc = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil)
          guard rc == SQLITE_OK, let handle else {
              sqlite3_close(handle)
              throw ReferenceDBError.cannotOpen(code: rc)
          }
          self.db = handle
      }

      /// Opens the `reference.sqlite` shipped as a `Bundle.module` resource.
      public static func bundled() throws -> ReferenceDB {
          guard let url = Bundle.module.url(forResource: "reference", withExtension: "sqlite") else {
              throw ReferenceDBError.missingBundleResource
          }
          return try ReferenceDB(url: url)
      }

      deinit { sqlite3_close(db) }

      /// `SELECT MaxCount FROM Items WHERE ItemDataID = ?` — nil if no such item.
      public func maxCount(itemDataID: Int) -> Int? {
          var stmt: OpaquePointer?
          guard sqlite3_prepare_v2(db, "SELECT MaxCount FROM Items WHERE ItemDataID = ?;", -1, &stmt, nil) == SQLITE_OK else {
              return nil
          }
          defer { sqlite3_finalize(stmt) }
          sqlite3_bind_int64(stmt, 1, Int64(itemDataID))
          guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
          return Int(sqlite3_column_int64(stmt, 0))
      }

      /// `SELECT I.TID, T.TID, T.MaxCount, T.DLCType FROM Ingredients I
      ///  JOIN Items T ON I.TID = T.ItemDataID` — parentID is the matched Items.TID.
      public func allIngredients() -> [IngredientRow] {
          var rows: [IngredientRow] = []
          var stmt: OpaquePointer?
          let sql = "SELECT I.TID, T.TID, T.MaxCount, T.DLCType FROM Ingredients I JOIN Items T ON I.TID = T.ItemDataID;"
          guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
          defer { sqlite3_finalize(stmt) }
          while sqlite3_step(stmt) == SQLITE_ROW {
              rows.append(IngredientRow(
                  id: Int(sqlite3_column_int64(stmt, 0)),
                  parentID: Int(sqlite3_column_int64(stmt, 1)),
                  maxCount: Int(sqlite3_column_int64(stmt, 2)),
                  dlcType: Int(sqlite3_column_int64(stmt, 3))
              ))
          }
          return rows
      }
  }
  ```

- [ ] **Step 5: Run the tests — GREEN.**
  Command: `swift test --filter ReferenceDBTests`
  Expected: PASS (4 tests).

- [ ] **Step 6: Commit.**
  Command:
  ```
  git add Sources/DaveSaveCore/ReferenceDB.swift Tests/DaveSaveCoreTests/TestSupport.swift Tests/DaveSaveCoreTests/ReferenceDBTests.swift
  git commit -m "feat: add read-only ReferenceDB over items/ingredients SQLite"
  ```

---

### Task 7: IngredientOps — Max-Own / Max-All on `SaveDocument`

**Files:**
- Create `Sources/DaveSaveCore/IngredientOps.swift` (extension on `SaveDocument`)
- Test `Tests/DaveSaveCoreTests/IngredientOpsTests.swift`

**Interfaces:**
- **Consumes (exact signatures from earlier tasks):**
  - `SaveCodec.encode(_ json: String) -> Data`, `SaveCodec.decode(_ data: Data) -> String`
  - `OrderedJSON` cases `.object([Member])`, `.array([OrderedJSON])`, `.scalar(String)`; `Member(keyLexeme:value:)` and `Member.key`
  - `OrderedJSON.value(at: [String]) -> OrderedJSON?`, `mutating setScalar(at: [String], lexeme: String) -> Bool`, `mutating setMember(at: [String], member: Member) -> Bool`
  - `SaveDocument.load(_ data: Data) throws -> SaveDocument`, `SaveDocument.encoded() -> Data`, and the SaveDocument task's `internal var root: OrderedJSON` (the live parsed DOM; same-module access).
  - `ReferenceDB.maxCount(itemDataID:) -> Int?`, `ReferenceDB.allIngredients() -> [IngredientRow]` (Task 6)
  - Test helper `makeTinyReferenceDB(at:)` (Task 6, same test module)
- **Produces (members declared on `SaveDocument` per the locked contract):**
  ```swift
  public mutating func maxOwnedIngredients(using ref: ReferenceDB)
  public mutating func maxAllIngredients(using ref: ReferenceDB)
  ```

- [ ] **Step 1: Write the failing tests `IngredientOpsTests.swift`.** Fixtures are synthetic compact JSON round-tripped through the codec; assertions compare the decoded re-serialized output byte-for-byte (and substring checks for the order-independent DLC-filter cases). The new-entry shape is asserted in exact key order: `ingredientsID, parentID, count, level=1, branchCount=0, isNew=true, placeTagMask=1, lastGainTime="04/01/2025 12:34:56", lastGainGameTime="10/03/2022 08:30:52"`.
  ```swift
  import Foundation
  import Testing
  @testable import DaveSaveCore

  @Suite struct IngredientOpsTests {
      private func freshDB() throws -> (ReferenceDB, URL) {
          let url = FileManager.default.temporaryDirectory
              .appendingPathComponent("ref-\(UUID().uuidString).sqlite")
          try makeTinyReferenceDB(at: url)
          return (try ReferenceDB(url: url), url)
      }

      private func loadDoc(_ json: String) throws -> SaveDocument {
          try SaveDocument.load(SaveCodec.encode(json))
      }

      @Test func maxOwnedSetsTieredCountOnExistingEntries() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          let json = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":5}}}"#
          var doc = try loadDoc(json)
          doc.maxOwnedIngredients(using: db)
          let out = SaveCodec.decode(doc.encoded())
          let expected = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":6666}}}"#
          #expect(out == expected)
      }

      @Test func maxOwnedDoesNotInjectMissingEntries() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          // Only 1020201 is owned; Max-Own must never add 1021011 etc.
          let json = #"{"Ingredients":{"1020201":{"ingredientsID":1020201,"count":5}}}"#
          var doc = try loadDoc(json)
          doc.maxOwnedIngredients(using: db)
          let out = SaveCodec.decode(doc.encoded())
          #expect(out == #"{"Ingredients":{"1020201":{"ingredientsID":1020201,"count":6666}}}"#)
      }

      @Test func maxAllInjectsMissingEntryWithNineKeyShape() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          // installedDLCs = [14252001] -> DLCType 1 kept, DLCType 5 (needs 14252401) filtered out.
          // 1020201 exists -> count updated; 1021011 (tier 66) injected; 1025901 (tier 0) skipped.
          let json = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":5}}}"#
          var doc = try loadDoc(json)
          doc.maxAllIngredients(using: db)
          let out = SaveCodec.decode(doc.encoded())
          let expected = #"{"PlayerInfo":{"m_Gold":100},"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{"1020201":{"ingredientsID":1020201,"count":6666},"1021011":{"ingredientsID":1021011,"parentID":1011701,"count":66,"level":1,"branchCount":0,"isNew":true,"placeTagMask":1,"lastGainTime":"04/01/2025 12:34:56","lastGainGameTime":"10/03/2022 08:30:52"}}}"#
          #expect(out == expected)
      }

      @Test func maxAllExcludesUninstalledDLCAndSkipsLowTier() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          let json = #"{"GameInfo":{"installedDLCs":[14252001]},"Ingredients":{}}"#
          var doc = try loadDoc(json)
          doc.maxAllIngredients(using: db)
          let out = SaveCodec.decode(doc.encoded())
          #expect(out.contains("1021011"))     // DLCType 0, tier 66 -> injected
          #expect(!out.contains("1027019"))    // DLCType 5 not installed -> excluded
          #expect(!out.contains("1025901"))    // MaxCount 1 -> tier 0 -> skipped
      }

      @Test func maxAllIncludesInstalledDLC() throws {
          let (db, url) = try freshDB()
          defer { try? FileManager.default.removeItem(at: url) }
          let json = #"{"GameInfo":{"installedDLCs":[14252001,14252401]},"Ingredients":{}}"#
          var doc = try loadDoc(json)
          doc.maxAllIngredients(using: db)
          let out = SaveCodec.decode(doc.encoded())
          #expect(out.contains("1027019"))     // DLCType 5 installed (14252401) -> injected
      }
  }
  ```

- [ ] **Step 2: Run the tests — RED (no ingredient ops yet).**
  Command: `swift test --filter IngredientOpsTests`
  Expected: FAIL (compile error: `SaveDocument` has no member `maxOwnedIngredients` / `maxAllIngredients`).

- [ ] **Step 3: Implement `IngredientOps.swift` to pass.** Mirrors `SaveGameManager::MaxOwnIngredients` / `MaxAllIngredients`: Max-Own looks up each owned entry's `ingredientsID` field (not the JSON key) and `setScalar`s `count`; Max-All iterates the DB join, applies the `{1:14252001,3:14252201,5:14252401}` DLC filter against `GameInfo.installedDLCs`, updates existing counts with `setScalar`, and injects missing entries with `setMember` in exact key order. Value-type DOM snapshots make the Max-Own loop safe against in-loop mutation.
  ```swift
  import Foundation

  public extension SaveDocument {
      /// Tier map (from SaveGameManager::GetDesiredMaxCountForTier):
      /// MaxCount >= 9999 -> 6666 ; >= 999 -> 666 ; >= 99 -> 66 ; else 0 (skip).
      private static func tierTarget(forMaxCount maxCount: Int) -> Int {
          if maxCount >= 9999 { return 6666 }
          if maxCount >= 999  { return 666 }
          if maxCount >= 99   { return 66 }
          return 0
      }

      /// DLCType -> the installedDLCs id that must be present to keep the ingredient.
      private static let dlcTypeToID: [Int: Int] = [1: 14252001, 3: 14252201, 5: 14252401]

      /// Max-Own: for every owned `Ingredients.<key>` that carries an `ingredientsID`,
      /// look up its `Items.MaxCount`, map to a tier target, and overwrite `count`.
      /// Never injects new entries.
      mutating func maxOwnedIngredients(using ref: ReferenceDB) {
          guard case .object(let members)? = root.value(at: ["Ingredients"]) else { return }
          for member in members {
              let key = member.key
              guard case .scalar(let idLexeme)? = member.value.value(at: ["ingredientsID"]),
                    let itemDataID = Int(idLexeme),
                    let maxCount = ref.maxCount(itemDataID: itemDataID) else { continue }
              let target = Self.tierTarget(forMaxCount: maxCount)
              guard target > 0 else { continue }
              _ = root.setScalar(at: ["Ingredients", key, "count"], lexeme: String(target))
          }
      }

      /// Max-All: iterate every reference ingredient, DLC-filter via installedDLCs,
      /// update existing counts, and inject missing entries with the full 9-key shape.
      mutating func maxAllIngredients(using ref: ReferenceDB) {
          var installed = Set<Int>()
          if case .array(let dlcs)? = root.value(at: ["GameInfo", "installedDLCs"]) {
              for entry in dlcs {
                  if case .scalar(let lexeme) = entry, let id = Int(lexeme) {
                      installed.insert(id)
                  }
              }
          }

          for row in ref.allIngredients() {
              if let needed = Self.dlcTypeToID[row.dlcType], !installed.contains(needed) {
                  continue
              }
              let target = Self.tierTarget(forMaxCount: row.maxCount)
              guard target > 0 else { continue }

              let key = String(row.id)
              if root.value(at: ["Ingredients", key]) != nil {
                  _ = root.setScalar(at: ["Ingredients", key, "count"], lexeme: String(target))
              } else {
                  let entry = OrderedJSON.object([
                      Member(keyLexeme: "\"ingredientsID\"",    value: .scalar(String(row.id))),
                      Member(keyLexeme: "\"parentID\"",         value: .scalar(String(row.parentID))),
                      Member(keyLexeme: "\"count\"",            value: .scalar(String(target))),
                      Member(keyLexeme: "\"level\"",            value: .scalar("1")),
                      Member(keyLexeme: "\"branchCount\"",      value: .scalar("0")),
                      Member(keyLexeme: "\"isNew\"",            value: .scalar("true")),
                      Member(keyLexeme: "\"placeTagMask\"",     value: .scalar("1")),
                      Member(keyLexeme: "\"lastGainTime\"",     value: .scalar("\"04/01/2025 12:34:56\"")),
                      Member(keyLexeme: "\"lastGainGameTime\"", value: .scalar("\"10/03/2022 08:30:52\"")),
                  ])
                  _ = root.setMember(at: ["Ingredients"], member: Member(keyLexeme: "\"\(key)\"", value: entry))
              }
          }
      }
  }
  ```

- [ ] **Step 4: Run the tests — GREEN.**
  Command: `swift test --filter IngredientOpsTests`
  Expected: PASS (5 tests).

- [ ] **Step 5: Run the full suite to confirm no regressions.**
  Command: `swift test`
  Expected: PASS (all suites, including Task 6).

- [ ] **Step 6: Commit.**
  Command:
  ```
  git add Sources/DaveSaveCore/IngredientOps.swift Tests/DaveSaveCoreTests/IngredientOpsTests.swift
  git commit -m "feat: add Max-Own/Max-All ingredient operations to SaveDocument"
  ```

---

### Task 8: SaveLocator — macOS save discovery

**Files:**
- Create `Sources/DaveSaveCore/SaveLocator.swift`
- Test `Tests/DaveSaveCoreTests/SaveLocatorTests.swift`

**Interfaces:**
- **Consumes:** nothing from earlier tasks (depends only on `Foundation`).
- **Produces** (later tasks / the app's open + write flow rely on these EXACT signatures):
  - `public struct SaveCandidate: Equatable { public let fileURL: URL; public let directoryURL: URL; public let modified: Date; public init(fileURL: URL, directoryURL: URL, modified: Date) }`
  - `public enum SaveLocator { public static func candidateRoots(home: URL) -> [URL]; public static func newestSave(fileManager: FileManager = .default, home: URL? = nil) -> SaveCandidate? }`

- [ ] **Step 1: Write the failing tests (RED).** Create `Tests/DaveSaveCoreTests/SaveLocatorTests.swift`:

```swift
import Foundation
import Testing
@testable import DaveSaveCore

struct SaveLocatorTests {

    private func uniqueHome() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SaveLocatorTests-\(UUID().uuidString)", isDirectory: true)
    }

    @discardableResult
    private func writeFile(_ url: URL, modified: Date) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xAB]).write(to: url)
        try fm.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }

    @Test func candidateRootsAreTheThreeKnownNexonRoots() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let roots = SaveLocator.candidateRoots(home: home)
        #expect(roots.count == 3)
        let suffixes = roots.map { $0.path.replacingOccurrences(of: home.path, with: "") }
        #expect(suffixes[0] == "/Library/Application Support/nexon/DAVE THE DIVER/SteamSData")
        #expect(suffixes[1] == "/Library/Application Support/nexon/DAVE THE DIVER/SData")
        #expect(suffixes[2] == "/Library/Application Support/com.nexon.dave/SteamSData")
    }

    @Test func newestSaveReturnsNilWhenNoSavesExist() {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        #expect(SaveLocator.newestSave(home: home) == nil)
    }

    @Test func newestSavePicksNewestAcrossRootAndNumericSubfolder() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let steam = SaveLocator.candidateRoots(home: home)[0]   // .../SteamSData

        // older manual save directly in the root
        try writeFile(steam.appendingPathComponent("m_old.sav"),
                      modified: Date(timeIntervalSince1970: 1_000))
        // numeric steam-id subfolder holding the newest autosave
        let idFolder = steam.appendingPathComponent("76561198000000000", isDirectory: true)
        let newest = try writeFile(idFolder.appendingPathComponent("GameSave0_GD.sav"),
                                   modified: Date(timeIntervalSince1970: 5_000))
        // decoy in a NON-numeric subfolder, even newer -> must be ignored
        try writeFile(steam.appendingPathComponent("backup_copies", isDirectory: true)
                        .appendingPathComponent("GameSave9_GD.sav"),
                      modified: Date(timeIntervalSince1970: 9_000))
        // decoy with a non-matching filename in the id folder, even newer -> must be ignored
        try writeFile(idFolder.appendingPathComponent("notes.sav"),
                      modified: Date(timeIntervalSince1970: 8_000))

        let candidate = SaveLocator.newestSave(home: home)
        #expect(candidate?.fileURL.lastPathComponent == "GameSave0_GD.sav")
        #expect(candidate?.directoryURL.lastPathComponent == "76561198000000000")
        #expect(candidate?.modified == Date(timeIntervalSince1970: 5_000))
        #expect(candidate?.fileURL.path == newest.path)
    }

    @Test func newestSaveMatchesManualSaveInFallbackRoot() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let fallback = SaveLocator.candidateRoots(home: home)[2]   // com.nexon.dave/SteamSData (verified primary)
        let f = try writeFile(fallback.appendingPathComponent("m_slot1.sav"),
                              modified: Date(timeIntervalSince1970: 2_000))
        let candidate = SaveLocator.newestSave(home: home)
        #expect(candidate?.fileURL.path == f.path)
        #expect(candidate?.directoryURL.lastPathComponent == "SData")
    }
}
```

- [ ] **Step 2: Run the tests — Expected: FAIL.** `swift test --filter SaveLocatorTests`
  (Fails to compile / link: `SaveLocator` and `SaveCandidate` do not exist yet.)

- [ ] **Step 3: Implement `SaveLocator` (GREEN).** Create `Sources/DaveSaveCore/SaveLocator.swift`:

```swift
import Foundation

public struct SaveCandidate: Equatable {
    public let fileURL: URL
    public let directoryURL: URL
    public let modified: Date

    public init(fileURL: URL, directoryURL: URL, modified: Date) {
        self.fileURL = fileURL
        self.directoryURL = directoryURL
        self.modified = modified
    }
}

public enum SaveLocator {

    /// The three known nexon save roots, rooted under `home`.
    public static func candidateRoots(home: URL) -> [URL] {
        let appSupport = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
        let nexon = appSupport
            .appendingPathComponent("nexon", isDirectory: true)
            .appendingPathComponent("DAVE THE DIVER", isDirectory: true)
        let comNexonDave = appSupport
            .appendingPathComponent("com.nexon.dave", isDirectory: true)   // VERIFIED real path: com.nexon.dave/SteamSData (no "DAVE THE DIVER" subfolder)
        return [
            nexon.appendingPathComponent("SteamSData", isDirectory: true),
            nexon.appendingPathComponent("SData", isDirectory: true),
            comNexonDave.appendingPathComponent("SteamSData", isDirectory: true),
        ]
    }

    /// For each existing root, scan the root itself plus every immediate all-ASCII-digit
    /// subfolder; match `GameSave*_GD.sav` / `m_*.sav`; return the globally-newest file
    /// (by `contentModificationDate`) along with the directory it was found in.
    public static func newestSave(fileManager: FileManager = .default, home: URL? = nil) -> SaveCandidate? {
        let resolvedHome = home ?? fileManager.homeDirectoryForCurrentUser
        var best: SaveCandidate?

        for root in candidateRoots(home: resolvedHome) {
            guard isDirectory(root, fileManager: fileManager) else { continue }

            var scanDirs: [URL] = [root]
            for sub in immediateSubdirectories(of: root, fileManager: fileManager)
            where isAllASCIIDigits(sub.lastPathComponent) {
                scanDirs.append(sub)
            }

            for dir in scanDirs {
                for file in saveFiles(in: dir, fileManager: fileManager) {
                    guard let modified = modificationDate(of: file) else { continue }
                    if best == nil || modified > best!.modified {
                        best = SaveCandidate(fileURL: file, directoryURL: dir, modified: modified)
                    }
                }
            }
        }
        return best
    }

    // MARK: - Matching helpers

    static func isAllASCIIDigits(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        for scalar in name.unicodeScalars where scalar.value < 48 || scalar.value > 57 {
            return false
        }
        return true
    }

    static func isSaveFileName(_ name: String) -> Bool {
        let isAutosave = name.hasPrefix("GameSave") && name.hasSuffix("_GD.sav")
        let isManual = name.hasPrefix("m_") && name.hasSuffix(".sav")
        return isAutosave || isManual
    }

    // MARK: - FileManager helpers

    private static func isDirectory(_ url: URL, fileManager: FileManager) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    private static func immediateSubdirectories(of url: URL, fileManager: FileManager) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.filter { entry in
            (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private static func saveFiles(in dir: URL, fileManager: FileManager) -> [URL] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.filter { entry in
            let isRegular = (try? entry.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            return isRegular && isSaveFileName(entry.lastPathComponent)
        }
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
```

- [ ] **Step 4: Run the tests — Expected: PASS.** `swift test --filter SaveLocatorTests`

- [ ] **Step 5: Commit.**
```bash
git add Sources/DaveSaveCore/SaveLocator.swift Tests/DaveSaveCoreTests/SaveLocatorTests.swift
git commit -m "feat: add SaveLocator macOS save discovery (known roots + numeric subfolders, newest by mtime)"
```

---

### Task 9: BackupStore — persistent timestamped backups + atomic write

**Files:**
- Create `Sources/DaveSaveCore/BackupStore.swift`
- Test `Tests/DaveSaveCoreTests/BackupStoreTests.swift`

**Interfaces:**
- **Consumes:** nothing from earlier tasks (depends only on `Foundation`).
- **Produces** (the app's write flow + Tier-1 in-app restore rely on these EXACT signatures):
  - `public enum BackupStore { public static func backupDirectory(bundleID: String, home: URL? = nil) -> URL; @discardableResult public static func backup(original: URL, bundleID: String, now: Date = Date(), home: URL? = nil) throws -> URL; public static func listBackups(bundleID: String, home: URL? = nil) -> [URL]; public static func writeAtomically(_ data: Data, to url: URL) throws }`

- [ ] **Step 1: Write the failing tests (RED).** Create `Tests/DaveSaveCoreTests/BackupStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import DaveSaveCore

struct BackupStoreTests {
    private let bundleID = "com.example.davesave"

    private func uniqueHome() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    /// Mirror the production formatter exactly so the expected filename is timezone-stable.
    private func expectedTimestamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: date)
    }

    @Test func backupDirectoryIsUnderAppSupportBundleBackups() {
        let home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        let dir = BackupStore.backupDirectory(bundleID: bundleID, home: home)
        #expect(dir.path == "/Users/tester/Library/Application Support/\(bundleID)/Backups")
    }

    @Test func backupWritesTimestampedFilenameAndCopiesBytes() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }

        let saveDir = home.appendingPathComponent("save", isDirectory: true)
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)
        let original = saveDir.appendingPathComponent("GameSave0_GD.sav")
        let payload = Data("hello-cjk-白毛鸡".utf8)
        try payload.write(to: original)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let backupURL = try BackupStore.backup(original: original, bundleID: bundleID, now: now, home: home)

        #expect(backupURL.lastPathComponent == "GameSave0_GD_\(expectedTimestamp(now)).sav")
        #expect(backupURL.deletingLastPathComponent().path
                == BackupStore.backupDirectory(bundleID: bundleID, home: home).path)
        #expect(try Data(contentsOf: backupURL) == payload)
    }

    @Test func listBackupsReturnsNewestFirstAndIgnoresNonSav() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let dir = BackupStore.backupDirectory(bundleID: bundleID, home: home)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fm = FileManager.default

        func make(_ name: String, _ modified: Date) throws -> URL {
            let u = dir.appendingPathComponent(name)
            try Data([0x00]).write(to: u)
            try fm.setAttributes([.modificationDate: modified], ofItemAtPath: u.path)
            return u
        }
        let older = try make("GameSave0_GD_20250101_000000.sav", Date(timeIntervalSince1970: 1_000))
        let newer = try make("GameSave0_GD_20260101_000000.sav", Date(timeIntervalSince1970: 9_000))
        _ = try make("README.txt", Date(timeIntervalSince1970: 5_000))   // must be ignored

        let list = BackupStore.listBackups(bundleID: bundleID, home: home)
        #expect(list.map { $0.lastPathComponent }
                == [newer.lastPathComponent, older.lastPathComponent])
    }

    @Test func writeAtomicallyWritesThenOverwrites() throws {
        let home = uniqueHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let target = home.appendingPathComponent("out.sav")

        try BackupStore.writeAtomically(Data("first".utf8), to: target)
        #expect(try Data(contentsOf: target) == Data("first".utf8))

        try BackupStore.writeAtomically(Data("second".utf8), to: target)
        #expect(try Data(contentsOf: target) == Data("second".utf8))
    }
}
```

- [ ] **Step 2: Run the tests — Expected: FAIL.** `swift test --filter BackupStoreTests`
  (Fails to compile / link: `BackupStore` does not exist yet.)

- [ ] **Step 3: Implement `BackupStore` (GREEN).** Create `Sources/DaveSaveCore/BackupStore.swift`:

```swift
import Foundation

public enum BackupStore {

    /// `~/Library/Application Support/<bundleID>/Backups/`
    public static func backupDirectory(bundleID: String, home: URL? = nil) -> URL {
        let resolvedHome = home ?? FileManager.default.homeDirectoryForCurrentUser
        return resolvedHome
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    /// Copy `original` into the backup directory as `<stem>_yyyyMMdd_HHmmss.sav`
    /// (en_US_POSIX, local time). Overwrites a same-second collision. Returns the backup URL.
    @discardableResult
    public static func backup(original: URL, bundleID: String, now: Date = Date(), home: URL? = nil) throws -> URL {
        let fileManager = FileManager.default
        let dir = backupDirectory(bundleID: bundleID, home: home)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let stem = original.deletingPathExtension().lastPathComponent
        let timestamp = timestampFormatter().string(from: now)
        let destination = dir.appendingPathComponent("\(stem)_\(timestamp).sav", isDirectory: false)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: original, to: destination)
        return destination
    }

    /// All `.sav` backups in the backup directory, newest `contentModificationDate` first.
    public static func listBackups(bundleID: String, home: URL? = nil) -> [URL] {
        let fileManager = FileManager.default
        let dir = backupDirectory(bundleID: bundleID, home: home)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let saves = entries.filter { url in
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            return isRegular && url.pathExtension == "sav"
        }
        return saves.sorted { lhs, rhs in
            let lDate = modificationDate(of: lhs)
            let rDate = modificationDate(of: rhs)
            if lDate != rDate { return lDate > rDate }
            return lhs.lastPathComponent > rhs.lastPathComponent
        }
    }

    /// Atomic write via `Data.write(options: .atomic)`.
    public static func writeAtomically(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Helpers

    private static func timestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }

    private static func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }
}
```

- [ ] **Step 4: Run the tests — Expected: PASS.** `swift test --filter BackupStoreTests`

- [ ] **Step 5: Commit.**
```bash
git add Sources/DaveSaveCore/BackupStore.swift Tests/DaveSaveCoreTests/BackupStoreTests.swift
git commit -m "feat: add BackupStore (persistent timestamped backups, newest-first listing, atomic write)"
```

## Test Fixtures

All fixtures below are **synthetic / anonymized** — hand-authored compact JSON or programmatically built SQLite, never a real user's save. They satisfy the Global Constraints fixture policy (CJK fixture + a non-`11090001` farm-animal fixture).

- **Compact ASCII sample** — inline string fixture used by `SaveCodecTests` / `SaveDocumentTests`, e.g. `{"PlayerInfo":{"m_Gold":12345,"m_Bei":678,"m_ChefFlame":90},"SNSInfo":{"m_Follow_Count":42}}`. Exercises the codec round-trip and the four currency paths; no whitespace (matches the game's on-disk style).
- **CJK sample (`白毛鸡`)** — inline string fixture used by `SaveCodecTests.cjkRoundTripHasNoReplacementChar` and `OrderedJSONTests`, e.g. `{"FarmAnimal":[{"FarmAnimalID":11090002,"Name":"白毛鸡"}]}` and the CJK key/value `"名前":"白毛鸡"`. Verifies UTF-16 XOR survives multi-byte content with zero `U+FFFD` and byte-identical re-encode.
- **Non-`11090001` farm-animal sample** — the `FarmAnimalID":11090002` entry above and the `Ingredients` key `14090007` in `OrderedJSONPathTests`. Deliberately avoids the `11090001` id that upstream silently corrupts, per fixture policy.
- **Tiny `reference.sqlite` for tests** — built at runtime by `makeTinyReferenceDB(at:)` in `Tests/DaveSaveCoreTests/TestSupport.swift` (Task 6), mirroring the real `Items`/`Ingredients` schema columns with four hand-picked rows that cover every tier (`9999→6666`, `99→66`, `1→skip`) and the DLC branches (`DLCType` 0/1/5). Distinct from the shipped `Sources/DaveSaveCore/Resources/reference.sqlite` (the real 563/305-row database generated in Task 1b); the test DB is anonymized, minimal, and disposable.

---

## Real-Save Validation (2026-06-28, on the maintainer's Apple Silicon Mac)

Before writing any code, the char-level codec design was validated against a REAL save
(`GameSave_00_GD.sav`, 458,905 bytes) located at
`~/Library/Application Support/com.nexon.dave/SteamSData/416443451/`:

- ✅ File is strict UTF-8; **char-level UTF-16 XOR (key "GameData") decodes to VALID JSON** (91 top-level keys).
- ✅ **Round-trip is byte-identical** (`encode(decode(x)) == x`) — the codec design is exactly correct.
- ✅ Save is **compact** (0 newlines/tabs, 0 `": "`) — the `OrderedJSON` byte-identity-by-lexeme assumption holds.
- ✅ Currency paths confirmed: `PlayerInfo.m_Gold`, `PlayerInfo.m_Bei`, `PlayerInfo.m_ChefFlame`, `SNSInfo.m_Follow_Count` all present and readable.
- ✅ `LastUpdateTime` = `639182153449994890` (a >2^53 big-int) — confirms whole-doc reserialization must be avoided.
- ✅ **Codec moat proven on real CJK data:** the save contains `白毛雞`/`放牧健康雞` (FarmAnimal names). Upstream's **byte-level** decode yields **121 U+FFFD corruption characters**; our **char-level** decode yields **0**. Upstream would corrupt this save; we do not.

**Path correction from this validation:** the real primary root on macOS is
`~/Library/Application Support/com.nexon.dave/SteamSData/<steamid>/` (no "DAVE THE DIVER" subfolder).
`SaveLocator.candidateRoots` and the Global Constraints have been updated accordingly (Task 8).

**Fixtures:** the real save is used for LOCAL (gitignored) round-trip validation only and is NEVER committed.
Committed test fixtures remain synthetic/anonymized, but are now known to match the real format
(compact, CJK FarmAnimal names, big-int `LastUpdateTime`, the four currency paths).
