import Foundation

public extension SaveDocument {
    /// Add a fish to the encyclopedia (`CaughtFish`), or raise the grade of one
    /// already present. The dict key is `String(fishID)`; the entry shape is
    /// `{fishID, grade, isNew}` (matching the game's own format).
    mutating func addCaughtFish(fishID: Int, grade: Int) {
        let key = String(fishID)
        if root.value(at: ["CaughtFish", key]) != nil {
            _ = root.setScalar(at: ["CaughtFish", key, "grade"], lexeme: String(grade))
        } else {
            let entry = OrderedJSON.object([
                Member(keyLexeme: "\"fishID\"", value: .scalar(String(fishID))),
                Member(keyLexeme: "\"grade\"",  value: .scalar(String(grade))),
                Member(keyLexeme: "\"isNew\"",  value: .scalar("true")),
            ])
            _ = root.setMember(at: ["CaughtFish"], member: Member(keyLexeme: "\"\(key)\"", value: entry))
        }
    }

    /// Low-level override: directly set an existing ingredient's `count`, bypassing the
    /// tier/DLC/aberration rules. Does nothing if the ingredient is not present.
    /// (Use with care — e.g. perishable aberration fish may still be discarded by the game.)
    mutating func setIngredientCount(id: Int, count: Int) {
        _ = root.setScalar(at: ["Ingredients", String(id), "count"], lexeme: String(count))
    }
}
