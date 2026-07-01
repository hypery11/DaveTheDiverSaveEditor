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

    // MARK: Constants — editable paths & clamp

    static let currencyClamp: Int64 = 999_999_999

    static let goldPath:     [String] = ["PlayerInfo", "m_Gold"]
    static let beiPath:      [String] = ["PlayerInfo", "m_Bei"]
    static let flamePath:    [String] = ["PlayerInfo", "m_ChefFlame"]
    static let followerPath: [String] = ["SNSInfo", "m_Follow_Count"]
    static let trustPath:    [String] = ["PlayerInfo", "m_trustPoint"]   // lowercase t
    static let fakePath:     [String] = ["PlayerInfo", "m_FakePoint"]    // uppercase F

    /// Dotted display path paired with its lookup path, in preview order.
    static let currencyPaths: [(dotted: String, path: [String])] = [
        ("PlayerInfo.m_Gold",       goldPath),
        ("PlayerInfo.m_Bei",        beiPath),
        ("PlayerInfo.m_ChefFlame",  flamePath),
        ("SNSInfo.m_Follow_Count",  followerPath),
        ("PlayerInfo.m_trustPoint", trustPath),
        ("PlayerInfo.m_FakePoint",  fakePath),
    ]

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

    // MARK: Currency getters

    public var gold: Int64          { intValue(at: Self.goldPath) }
    public var bei: Int64           { intValue(at: Self.beiPath) }
    public var artisansFlame: Int64 { intValue(at: Self.flamePath) }
    public var followerCount: Int64 { intValue(at: Self.followerPath) }
    public var trustPoint: Int64    { intValue(at: Self.trustPath) }
    public var fakePoint: Int64     { intValue(at: Self.fakePath) }

    // MARK: Currency setters

    public mutating func setGold(_ v: Int64) {
        setInt(min(v, Self.currencyClamp), at: Self.goldPath)
    }

    public mutating func setBei(_ v: Int64) {
        setInt(min(v, Self.currencyClamp), at: Self.beiPath)
    }

    public mutating func setArtisansFlame(_ v: Int64) {
        setInt(min(v, Self.currencyClamp), at: Self.flamePath)
    }

    public mutating func setFollowerCount(_ v: Int64) {
        setInt(v, at: Self.followerPath)   // unclamped (matches upstream)
    }

    public mutating func setTrustPoint(_ v: Int64) {
        setInt(min(v, Self.currencyClamp), at: Self.trustPath)
    }

    public mutating func setFakePoint(_ v: Int64) {
        setInt(min(v, Self.currencyClamp), at: Self.fakePath)
    }

    // MARK: Pending-change diff (preview)

    /// Diff the current document against the load-time snapshot over the four
    /// known editable currency paths. Reports `old -> new` verbatim lexemes.
    public func pendingChanges() -> [FieldChange] {
        var changes: [FieldChange] = []
        for entry in Self.currencyPaths {
            let oldValue = Self.scalarLexeme(in: originalRoot, at: entry.path) ?? ""
            let newValue = Self.scalarLexeme(in: root,         at: entry.path) ?? ""
            if oldValue != newValue {
                changes.append(FieldChange(path: entry.dotted,
                                           oldValue: oldValue,
                                           newValue: newValue))
            }
        }
        return changes
    }
}
