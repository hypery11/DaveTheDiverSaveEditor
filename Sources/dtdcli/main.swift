// dtdcli — a tiny headless companion to the Dave The Diver Save Editor.
// Uses the exact same DaveSaveCore engine as the SwiftUI app. Every write makes
// a timestamped backup first (in ~/Library/Application Support/<bundleID>/Backups).
import Foundation
import DaveSaveCore

func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    die("""
    usage: dtdcli <command> <savefile> [value]
      read                      print Gold/Bei/Artisan's Flame/Followers
      set-gold     <n>          set gold (clamped 999,999,999) + backup + write
      set-bei      <n>          set bei  (clamped) + backup + write
      set-flame    <n>          set Artisan's Flame (clamped) + backup + write
      set-follower <n>          set follower count (unclamped) + backup + write
      max-ingredients           max all ingredients (DLC-aware) + backup + write
    """)
}

let cmd = args[1]
let url = URL(fileURLWithPath: args[2])
let bundleID = "app.davethediver.saveeditor.cli"

guard let raw = try? Data(contentsOf: url) else { die("cannot read \(url.path)") }
var doc: SaveDocument
do { doc = try SaveDocument.load(raw) }
catch { die("not a valid Dave the Diver save: \(error)") }

func show(_ d: SaveDocument) {
    print("  Gold=\(d.gold)  Bei=\(d.bei)  Artisan'sFlame=\(d.artisansFlame)  Followers=\(d.followerCount)")
}

func writeBack(_ d: SaveDocument) {
    // Safety: refuse to write while the game is running or the file is held open.
    // Override with DTD_FORCE=1 (e.g. when writing to a copy for testing).
    if ProcessInfo.processInfo.environment["DTD_FORCE"] == nil,
       let reason = SaveGuard.check(saveURL: url).blockReason {
        die("refusing to write: \(reason)\n(set DTD_FORCE=1 to override)")
    }
    do {
        let backup = try BackupStore.backup(original: url, bundleID: bundleID)
        let out = d.encoded()
        try BackupStore.writeAtomically(out, to: url)
        let onDisk = try Data(contentsOf: url)
        let reloaded = try SaveDocument.load(onDisk)
        print("WROTE \(out.count) bytes  (backup: \(backup.path))")
        print("on-disk bytes == freshly-encoded bytes: \(out == onDisk)")
        print("reload after write:")
        show(reloaded)
    } catch { die("write failed: \(error)") }
}

func intArg() -> Int64 {
    guard args.count >= 4, let v = Int64(args[3]) else { die("need a numeric value") }
    return v
}

print("loaded \(url.lastPathComponent):")
show(doc)

switch cmd {
case "read":
    break
case "dump":
    // Decode the save to plain JSON for inspection. Read-only: never writes the save.
    let outPath = args.count >= 4 ? args[3] : url.path + ".json"
    let json = SaveCodec.decode(raw)
    do { try Data(json.utf8).write(to: URL(fileURLWithPath: outPath)) }
    catch { die("dump write failed: \(error)") }
    print("dumped \(json.count) chars to \(outPath)")
case "set-gold":     doc.setGold(intArg());          writeBack(doc)
case "set-bei":      doc.setBei(intArg());           writeBack(doc)
case "set-flame":    doc.setArtisansFlame(intArg());  writeBack(doc)
case "set-follower": doc.setFollowerCount(intArg());  writeBack(doc)
case "max-ingredients":
    guard let ref = try? ReferenceDB.bundled() else { die("cannot open reference DB") }
    doc.maxAllIngredients(using: ref)
    writeBack(doc)
case "batch":
    // Remaining args (from index 3) are ops: gold=N bei=N flame=N follower=N maxown maxall
    var ref: ReferenceDB? = nil
    func db() -> ReferenceDB { if ref == nil { ref = try? ReferenceDB.bundled() }; guard let r = ref else { die("cannot open reference DB") }; return r }
    for a in args.dropFirst(3) {
        if a == "maxown" { doc.maxOwnedIngredients(using: db()); print("  + max own ingredients") }
        else if a == "maxall" { doc.maxAllIngredients(using: db()); print("  + max all ingredients") }
        else if a == "maxbranch" { doc.maxBranchIngredients(using: db()); print("  + max branch (second store) ingredient counts") }
        else if a == "maxinv" { let n = doc.maxInventoryItems(using: db()); print("  + max inventory items (\(n) slots)") }
        else if a == "maxmerman" { let n = doc.maxMermanInventory(); print("  + max merman village inventory (\(n) slots)") }
        else if a == "maxseeds" { let n = doc.maxFarmStorage(); print("  + max farm seed/produce storage (\(n) stacks)") }
        else if a == "maxcraft" { let n = doc.maxCraftMaterials(using: db()); print("  + max craft materials (\(n) slots raised/injected)") }
        else if a.hasPrefix("setinv=") {
            let parts = a.dropFirst(7).split(separator: ":").map(String.init)
            guard parts.count == 2, let id = Int(parts[0]), let c = Int(parts[1]) else { die("bad setinv op: \(a)") }
            let ok = doc.setInventoryItem(itemID: id, count: c); print("  + set inventory item \(id) = \(c) (\(ok ? "ok" : "no container"))")
        }
        else if a.hasPrefix("gold="), let v = Int64(a.dropFirst(5)) { doc.setGold(v) }
        else if a.hasPrefix("bei="), let v = Int64(a.dropFirst(4)) { doc.setBei(v) }
        else if a.hasPrefix("flame="), let v = Int64(a.dropFirst(6)) { doc.setArtisansFlame(v) }
        else if a.hasPrefix("follower="), let v = Int64(a.dropFirst(9)) { doc.setFollowerCount(v) }
        else if a.hasPrefix("research="), let v = Int64(a.dropFirst(9)) { doc.setResearchPoint(v) }
        else if a.hasPrefix("addfish=") {
            let parts = a.dropFirst(8).split(separator: ":").map(String.init)
            guard let id = Int(parts.first ?? "") else { die("bad addfish op: \(a)") }
            let g = parts.count > 1 ? (Int(parts[1]) ?? 3) : 3
            doc.addCaughtFish(fishID: id, grade: g); print("  + caught fish \(id) (grade \(g))")
        }
        else if a.hasPrefix("seting=") {
            let parts = a.dropFirst(7).split(separator: ":").map(String.init)
            guard parts.count == 2, let id = Int(parts[0]), let c = Int(parts[1]) else { die("bad seting op: \(a)") }
            doc.setIngredientCount(id: id, count: c); print("  + set ingredient \(id) = \(c)")
        }
        else { die("unknown batch op: \(a)") }
    }
    writeBack(doc)
default:
    die("unknown command: \(cmd)")
}
