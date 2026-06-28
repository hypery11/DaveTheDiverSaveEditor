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
    // MARK: Research Point (a spendable resource, like the currencies)

    /// `PlayerInfo.m_researchPoint`.
    var researchPoint: Int64 {
        if case .scalar(let s)? = root.value(at: ["PlayerInfo", "m_researchPoint"]), let v = Int64(s) { return v }
        return 0
    }

    /// Set research points (clamped to the same 0...999,999,999 range as the currencies).
    mutating func setResearchPoint(_ value: Int64) {
        let clamped = max(0, min(value, 999_999_999))
        _ = root.setScalar(at: ["PlayerInfo", "m_researchPoint"], lexeme: String(clamped))
    }

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
}
