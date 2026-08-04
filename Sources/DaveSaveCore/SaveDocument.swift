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

    // MARK: Editable scalar table — the single source of truth for every currency-like value

    static let currencyClamp: Int64 = 999_999_999

    /// One row per editable scalar: a stable `id` (matches the app's `Currency.rawValue`),
    /// the dotted display path (write preview), the lookup path, and an inclusive `[lo, hi]`
    /// clamp. Read / write / diff / reset all derive from this table, so adding an editable
    /// value is a single row here + a `Currency` case — no scattered getters, setters, or
    /// dictionary literals to keep in sync.
    static let editableScalars: [(id: String, dotted: String, path: [String], lo: Int64, hi: Int64)] = [
        ("gold",          "PlayerInfo.m_Gold",         ["PlayerInfo", "m_Gold"],           .min, currencyClamp),
        ("bei",           "PlayerInfo.m_Bei",          ["PlayerInfo", "m_Bei"],            .min, currencyClamp),
        ("artisansFlame", "PlayerInfo.m_ChefFlame",    ["PlayerInfo", "m_ChefFlame"],      .min, currencyClamp),
        ("followerCount", "SNSInfo.m_Follow_Count",    ["SNSInfo", "m_Follow_Count"],      .min, .max),          // unclamped
        ("researchPoint", "PlayerInfo.m_researchPoint",["PlayerInfo", "m_researchPoint"],  0,    currencyClamp), // floors at 0
        ("trustPoint",    "PlayerInfo.m_trustPoint",   ["PlayerInfo", "m_trustPoint"],     .min, currencyClamp),
        ("fakePoint",     "PlayerInfo.m_FakePoint",    ["PlayerInfo", "m_FakePoint"],      .min, currencyClamp),
    ]

    private static func spec(_ id: String) -> (dotted: String, path: [String], lo: Int64, hi: Int64)? {
        editableScalars.first { $0.id == id }.map { ($0.dotted, $0.path, $0.lo, $0.hi) }
    }

    /// The dotted JSON path an editable scalar writes to. Exposed so the app can label a
    /// `FieldChange` with the row name the user actually clicked, instead of showing them
    /// `PlayerInfo.m_ChefFlame`, while the mapping itself stays owned by the table above.
    public static func dottedPath(forID id: String) -> String? {
        spec(id)?.dotted
    }

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

    /// Indented, order-preserving JSON of the whole save (for the read-only Raw view).
    public func prettyJSON() -> String {
        root.prettyPrinted()
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

    // MARK: Generic accessors (drive off `editableScalars`)

    /// Current value for an editable-scalar `id` (0 if the id is unknown or its path absent).
    public func intValue(forID id: String) -> Int64 {
        guard let s = Self.spec(id) else { return 0 }
        return intValue(at: s.path)
    }

    /// Set an editable scalar by `id`, clamped to its inclusive `[lo, hi]`. No-op (returns
    /// false) for an unknown id or a missing path.
    @discardableResult
    public mutating func setInt(_ value: Int64, forID id: String) -> Bool {
        guard let s = Self.spec(id) else { return false }
        return setInt(max(s.lo, min(value, s.hi)), at: s.path)
    }

    // MARK: Typed convenience accessors (thin wrappers over the table; used by CLI/tests)

    public var gold: Int64          { intValue(forID: "gold") }
    public var bei: Int64           { intValue(forID: "bei") }
    public var artisansFlame: Int64 { intValue(forID: "artisansFlame") }
    public var followerCount: Int64 { intValue(forID: "followerCount") }
    public var researchPoint: Int64 { intValue(forID: "researchPoint") }
    public var trustPoint: Int64    { intValue(forID: "trustPoint") }
    public var fakePoint: Int64     { intValue(forID: "fakePoint") }

    public mutating func setGold(_ v: Int64)          { setInt(v, forID: "gold") }
    public mutating func setBei(_ v: Int64)           { setInt(v, forID: "bei") }
    public mutating func setArtisansFlame(_ v: Int64) { setInt(v, forID: "artisansFlame") }
    public mutating func setFollowerCount(_ v: Int64) { setInt(v, forID: "followerCount") }
    public mutating func setResearchPoint(_ v: Int64) { setInt(v, forID: "researchPoint") }
    public mutating func setTrustPoint(_ v: Int64)    { setInt(v, forID: "trustPoint") }
    public mutating func setFakePoint(_ v: Int64)     { setInt(v, forID: "fakePoint") }

    // MARK: Pending-change diff (preview)

    /// Diff the current document against the load-time snapshot over every editable
    /// scalar in `editableScalars`. Reports `old -> new` verbatim lexemes, in table order.
    public func pendingChanges() -> [FieldChange] {
        Self.editableScalars.compactMap { s in
            let oldValue = Self.scalarLexeme(in: originalRoot, at: s.path) ?? ""
            let newValue = Self.scalarLexeme(in: root,         at: s.path) ?? ""
            return oldValue == newValue
                ? nil
                : FieldChange(path: s.dotted, oldValue: oldValue, newValue: newValue)
        }
    }
}
