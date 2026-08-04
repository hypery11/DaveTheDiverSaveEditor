import Foundation

public extension SaveDocument {
    /// Raise every owned seed / produce stock in the home farm's storage. `Farm.Storage`
    /// is an array of `{ID, Count, Value, Name, IsNew}`; entries with `ID == 0` are empty
    /// slots and are left untouched. Returns the number of stacks raised.
    @discardableResult
    mutating func maxFarmStorage(to target: Int = 9999) -> Int {
        guard case .array(var elements)? = root.value(at: ["Farm", "Storage"]) else { return 0 }
        var changed = 0
        for i in elements.indices {
            guard case .scalar(let idLexeme)? = elements[i].value(at: ["ID"]),
                  let id = Int(idLexeme), id != 0,
                  case .scalar(let countLexeme)? = elements[i].value(at: ["Count"]),
                  let current = Int(countLexeme), current < target else { continue }
            _ = elements[i].setScalar(at: ["Count"], lexeme: String(target))
            changed += 1
        }
        guard changed > 0 else { return 0 }
        _ = root.setMember(at: ["Farm"], member: Member(keyLexeme: "\"Storage\"", value: .array(elements)))
        return changed
    }
}
