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

    // MARK: Object-keyed "raise a field" ops (share one combinator)

    /// For every member of the object at `containerPath`, if its child `field` is an integer
    /// in `[floor, target)`, raise it to `target`. This is the one place the guard / parse /
    /// setScalar / count dance lives; merman / staff / fish all fold onto it. Returns the
    /// number of members changed. (Inventory items use a reference-DB tier map, and farm
    /// storage iterates an array, so those legitimately stay separate.)
    @discardableResult
    mutating func raiseIntField(inObjectAt containerPath: [String], field: String, to target: Int, floor: Int = 0) -> Int {
        guard case .object(let members)? = root.value(at: containerPath) else { return 0 }
        var changed = 0
        for member in members {
            guard case .scalar(let s)? = member.value.value(at: [field]),
                  let current = Int(s), current >= floor, current < target else { continue }
            _ = root.setScalar(at: containerPath + [member.key, field], lexeme: String(target))
            changed += 1
        }
        return changed
    }

    /// Raise every `MermanVillInventory.<key>.count` to 999 (skips negative markers).
    @discardableResult
    mutating func maxMermanInventory() -> Int {
        raiseIntField(inObjectAt: ["MermanVillInventory"], field: "count", to: 999)
    }

    /// Level every hired `Staff.<guid>.level` to `target` (default 20 — the observed cap).
    @discardableResult
    mutating func maxStaffLevels(to target: Int = 20) -> Int {
        raiseIntField(inObjectAt: ["Staff"], field: "level", to: target)
    }

    /// Record the top `grade` (default 5) for every fish already in `CaughtFish` — does NOT
    /// add uncaught fish (`grade` is a standalone int with no coupled derived field).
    @discardableResult
    mutating func maxCaughtFishGrades(to target: Int = 5) -> Int {
        raiseIntField(inObjectAt: ["CaughtFish"], field: "grade", to: target)
    }
}
