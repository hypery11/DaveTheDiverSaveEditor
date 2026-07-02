import Foundation

/// Same tier mapping the ingredient logic uses (SaveGameManager::GetDesiredMaxCountForTier):
/// MaxCount >= 9999 -> 6666 ; >= 999 -> 666 ; >= 99 -> 66 ; else 0 (skip).
private func inventoryTierTarget(forMaxCount maxCount: Int) -> Int {
    if maxCount >= 9999 { return 6666 }
    if maxCount >= 999  { return 666 }
    if maxCount >= 99   { return 66 }
    return 0
}

public extension SaveDocument {
    // Research Point (`PlayerInfo.m_researchPoint`) is now an `editableScalars` row in
    // SaveDocument.swift — its getter/setter live there with the other currency-likes.

    // MARK: General inventory items (materials, crafting parts, ...)

    /// Max owned general inventory items. For every `InventoryItemSlot.<key>`:
    /// - skip the special `totalCount == -1` entries (unique / key items),
    /// - if the item is a known stackable in the reference `Items` table, raise
    ///   `totalCount` to the same tier target the ingredients use,
    /// - otherwise, if it is demonstrably stackable (current count > 1), raise it to 999.
    /// Items at count 1 that are unknown to the reference DB are left untouched
    /// (they are likely unique). Returns the number of slots changed.
    @discardableResult
    mutating func maxInventoryItems(using ref: ReferenceDB) -> Int {
        guard case .object(let members)? = root.value(at: ["InventoryItemSlot"]) else { return 0 }
        var changed = 0
        for member in members {
            let key = member.key
            guard case .scalar(let idLexeme)? = member.value.value(at: ["itemID"]),
                  let itemID = Int(idLexeme),
                  case .scalar(let countLexeme)? = member.value.value(at: ["totalCount"]),
                  let current = Int(countLexeme),
                  current >= 0 else { continue }   // skip totalCount == -1 (special)

            var target = 0
            if let maxCount = ref.maxCount(itemDataID: itemID) {
                target = inventoryTierTarget(forMaxCount: maxCount)
            } else if current > 1 {
                target = 999
            }
            guard target > current else { continue }
            _ = root.setScalar(at: ["InventoryItemSlot", key, "totalCount"], lexeme: String(target))
            changed += 1
        }
        return changed
    }

    // MARK: Merman Village inventory

    /// Raise every `MermanVillInventory.<key>.count` to 999 (skips negative markers).
    /// Returns the number of slots changed.
    @discardableResult
    mutating func maxMermanInventory() -> Int {
        guard case .object(let members)? = root.value(at: ["MermanVillInventory"]) else { return 0 }
        var changed = 0
        for member in members {
            let key = member.key
            guard case .scalar(let c)? = member.value.value(at: ["count"]),
                  let current = Int(c), current >= 0, current < 999 else { continue }
            _ = root.setScalar(at: ["MermanVillInventory", key, "count"], lexeme: "999")
            changed += 1
        }
        return changed
    }

    // MARK: Staff levels

    /// Raise every hired `Staff.<guid>.level` to `target` (default 20 — the observed cap;
    /// most staff in a maxed save already sit there). `level` is a standalone int with no
    /// coupled derived field, so this is safe. Returns the number of staff raised.
    @discardableResult
    mutating func maxStaffLevels(to target: Int = 20) -> Int {
        guard case .object(let members)? = root.value(at: ["Staff"]) else { return 0 }
        var changed = 0
        for member in members {
            let key = member.key
            guard case .scalar(let l)? = member.value.value(at: ["level"]),
                  let current = Int(l), current < target else { continue }
            _ = root.setScalar(at: ["Staff", key, "level"], lexeme: String(target))
            changed += 1
        }
        return changed
    }

    // MARK: Caught-fish grades

    /// Raise every `CaughtFish.<id>.grade` to `target` (default 5 — the top grade), i.e.
    /// record the best size caught for every fish already in the encyclopedia. `grade` is a
    /// standalone int; this does NOT add uncaught fish. Returns the number of records raised.
    @discardableResult
    mutating func maxCaughtFishGrades(to target: Int = 5) -> Int {
        guard case .object(let members)? = root.value(at: ["CaughtFish"]) else { return 0 }
        var changed = 0
        for member in members {
            let key = member.key
            guard case .scalar(let g)? = member.value.value(at: ["grade"]),
                  let current = Int(g), current < target else { continue }
            _ = root.setScalar(at: ["CaughtFish", key, "grade"], lexeme: String(target))
            changed += 1
        }
        return changed
    }
}
