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

    /// DLCType 1 is the DREDGE collab "aberration" fish. These are PERISHABLE — the
    /// game does not let them carry over between nights and discards any leftover on
    /// load ("rotten aberration fish discarded"). Maxing their count therefore does
    /// nothing useful and actively triggers that discard, so they must be skipped.
    private static let aberrationDLCType = 1

    /// All ingredient IDs that are non-storable aberrations (DLCType 1), so both
    /// max operations can skip them.
    private static func aberrationIDs(in ref: ReferenceDB) -> Set<Int> {
        Set(ref.allIngredients().filter { $0.dlcType == aberrationDLCType }.map { $0.id })
    }

    /// Max-Own: for every owned `Ingredients.<key>` that carries an `ingredientsID`,
    /// look up its `Items.MaxCount`, map to a tier target, and overwrite `count`.
    /// Never injects new entries. Skips perishable aberration fish.
    mutating func maxOwnedIngredients(using ref: ReferenceDB) {
        let aberrations = Self.aberrationIDs(in: ref)
        guard case .object(let members)? = root.value(at: ["Ingredients"]) else { return }
        for member in members {
            let key = member.key
            guard case .scalar(let idLexeme)? = member.value.value(at: ["ingredientsID"]),
                  let itemDataID = Int(idLexeme),
                  !aberrations.contains(itemDataID),
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
            if row.dlcType == Self.aberrationDLCType { continue }   // perishable aberration fish: never max
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
