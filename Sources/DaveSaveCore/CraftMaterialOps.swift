import Foundation

public extension SaveDocument {
    /// DLCType -> the installedDLCs id required to keep the material (same map the
    /// ingredient logic uses). DLCType 0 is base content and always allowed.
    private static let craftDLCTypeToID: [Int: Int] = [1: 14252001, 3: 14252201, 5: 14252401]

    /// Ensure every craft material (ItemType 6: fish parts, DREDGE research parts / bones)
    /// the player's installed DLCs allow is present in `InventoryItemSlot` at `target`,
    /// raising owned stacks and injecting missing ones. These are non-perishable (unlike
    /// raw aberration fish), so injection is safe. Returns the number of slots raised or
    /// created.
    @discardableResult
    mutating func maxCraftMaterials(using ref: ReferenceDB, to target: Int = 999) -> Int {
        var installed = Set<Int>()
        if case .array(let dlcs)? = root.value(at: ["GameInfo", "installedDLCs"]) {
            for entry in dlcs { if case .scalar(let l) = entry, let id = Int(l) { installed.insert(id) } }
        }
        let wanted = ref.craftMaterials().filter { row in
            guard let needed = Self.craftDLCTypeToID[row.dlcType] else { return true }  // DLCType 0
            return installed.contains(needed)
        }

        var ownedKey: [Int: String] = [:]
        var nextIndex = 0
        if case .object(let members)? = root.value(at: ["InventoryItemSlot"]) {
            for m in members {
                if case .scalar(let idl)? = m.value.value(at: ["itemID"]), let id = Int(idl) { ownedKey[id] = m.key }
                if case .scalar(let ixl)? = m.value.value(at: ["index"]), let ix = Int(ixl), ix + 1 > nextIndex { nextIndex = ix + 1 }
            }
        }

        var changed = 0
        for row in wanted {
            if let key = ownedKey[row.id] {
                guard case .scalar(let cl)? = root.value(at: ["InventoryItemSlot", key, "totalCount"]),
                      let current = Int(cl), current >= 0, current < target else { continue }
                _ = root.setScalar(at: ["InventoryItemSlot", key, "totalCount"], lexeme: String(target))
                changed += 1
            } else if injectInventorySlot(itemID: row.id, count: target, index: nextIndex) {
                nextIndex += 1
                changed += 1
            }
        }
        return changed
    }

    /// Set an existing `InventoryItemSlot` entry's `totalCount`, or inject a new slot if
    /// the item is absent. Returns true if a slot was changed or created. Does nothing if
    /// the save has no `InventoryItemSlot` container.
    @discardableResult
    mutating func setInventoryItem(itemID: Int, count: Int) -> Bool {
        guard case .object(let members)? = root.value(at: ["InventoryItemSlot"]) else { return false }
        var nextIndex = 0
        for m in members {
            if case .scalar(let ixl)? = m.value.value(at: ["index"]), let ix = Int(ixl), ix + 1 > nextIndex { nextIndex = ix + 1 }
        }
        for m in members {
            if case .scalar(let idl)? = m.value.value(at: ["itemID"]), Int(idl) == itemID {
                return root.setScalar(at: ["InventoryItemSlot", m.key, "totalCount"], lexeme: String(count))
            }
        }
        return injectInventorySlot(itemID: itemID, count: count, index: nextIndex)
    }

    /// Inject a `{GUID, index, itemID, totalCount, isNew}` slot under InventoryItemSlot,
    /// keyed by a fresh GUID (matching the game's own shape).
    private mutating func injectInventorySlot(itemID: Int, count: Int, index: Int) -> Bool {
        guard case .object? = root.value(at: ["InventoryItemSlot"]) else { return false }
        let guid = UUID().uuidString.lowercased()
        let entry = OrderedJSON.object([
            Member(keyLexeme: "\"GUID\"",       value: .scalar("\"\(guid)\"")),
            Member(keyLexeme: "\"index\"",      value: .scalar(String(index))),
            Member(keyLexeme: "\"itemID\"",     value: .scalar(String(itemID))),
            Member(keyLexeme: "\"totalCount\"", value: .scalar(String(count))),
            Member(keyLexeme: "\"isNew\"",      value: .scalar("true")),
        ])
        return root.setMember(at: ["InventoryItemSlot"], member: Member(keyLexeme: "\"\(guid)\"", value: entry))
    }
}
