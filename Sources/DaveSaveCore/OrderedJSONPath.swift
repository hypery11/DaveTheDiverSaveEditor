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
