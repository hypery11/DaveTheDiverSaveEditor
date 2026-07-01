// OrderedJSON — lexeme-preserving JSON DOM.
// Pure Swift, no Foundation. Every untouched token re-emits its verbatim source
// lexeme, so decode -> parse -> serialize with zero edits is byte-identical for
// compact input (the game writes compact JSON). Numbers/bool/null are stored as
// their raw source text; strings keep their surrounding quotes and escapes.

public indirect enum OrderedJSON: Equatable {
    case object([Member])
    case array([OrderedJSON])
    /// VERBATIM source lexeme of the value token:
    /// numbers/bool/null as-is ("999999999","true","null");
    /// strings INCLUDING surrounding quotes & escapes (#""abc""#).
    case scalar(String)
}

public struct Member: Equatable {
    /// Verbatim key token INCLUDING quotes, e.g. #""m_Gold""#.
    public var keyLexeme: String
    public var value: OrderedJSON

    public init(keyLexeme: String, value: OrderedJSON) {
        self.keyLexeme = keyLexeme
        self.value = value
    }

    /// Decoded key: surrounding quotes stripped + JSON escapes resolved.
    public var key: String {
        OrderedJSON.decodeStringLexeme(keyLexeme)
    }
}

public enum JSONParseError: Error, Equatable {
    case unexpectedEnd
    case unexpectedCharacter(Int)
    case invalidNumber(Int)
    /// Thrown when object/array nesting exceeds the parser's recursion limit.
    case tooDeeplyNested(Int)
}

// MARK: - Parsing

public extension OrderedJSON {

    /// Recursive-descent parser that captures verbatim lexemes for scalars and keys.
    /// Skips insignificant whitespace between tokens (a no-op for compact input).
    /// Throws `JSONParseError.tooDeeplyNested` when nesting exceeds 128 levels.
    static func parse(_ text: String) throws -> OrderedJSON {
        var parser = Parser(text)
        let value = try parser.parseValue(depth: 0)
        parser.skipWhitespace()
        guard parser.isAtEnd else {
            throw JSONParseError.unexpectedCharacter(parser.position)
        }
        return value
    }

    /// Compact serialization: no whitespace, lexemes emitted verbatim.
    func serialized() -> String {
        switch self {
        case .scalar(let lexeme):
            return lexeme
        case .array(let elements):
            var s = "["
            for (i, element) in elements.enumerated() {
                if i > 0 { s += "," }
                s += element.serialized()
            }
            s += "]"
            return s
        case .object(let members):
            var s = "{"
            for (i, member) in members.enumerated() {
                if i > 0 { s += "," }
                s += member.keyLexeme
                s += ":"
                s += member.value.serialized()
            }
            s += "}"
            return s
        }
    }

    /// Indented, human-readable serialization (2-space) preserving member order.
    /// Emits the same verbatim lexemes as `serialized()`, so re-parsing the result
    /// and `serialized()`-ing it reproduces the compact original — it's lossless.
    /// Read-only view aid; the editor never writes this back.
    func prettyPrinted(indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        let pad1 = String(repeating: "  ", count: indent + 1)
        switch self {
        case .scalar(let lexeme):
            return lexeme
        case .array(let elements):
            if elements.isEmpty { return "[]" }
            var s = "[\n"
            for (i, element) in elements.enumerated() {
                s += pad1 + element.prettyPrinted(indent: indent + 1)
                s += i < elements.count - 1 ? ",\n" : "\n"
            }
            return s + pad + "]"
        case .object(let members):
            if members.isEmpty { return "{}" }
            var s = "{\n"
            for (i, member) in members.enumerated() {
                s += pad1 + member.keyLexeme + ": " + member.value.prettyPrinted(indent: indent + 1)
                s += i < members.count - 1 ? ",\n" : "\n"
            }
            return s + pad + "}"
        }
    }
}

// MARK: - Key/string lexeme decoding

extension OrderedJSON {

    /// Decode a verbatim JSON string lexeme (with surrounding quotes) into its value:
    /// strips the quotes and resolves \" \\ \/ \n \t \r \b \f and \uXXXX
    /// (including UTF-16 surrogate pairs). Returns the input unchanged if it is not a
    /// quoted string (defensive; never the case for valid keys).
    static func decodeStringLexeme(_ lexeme: String) -> String {
        let chars = Array(lexeme)
        guard chars.count >= 2, chars.first == "\"", chars.last == "\"" else {
            return lexeme
        }
        var result = ""
        var i = 1
        let end = chars.count - 1   // index of the closing quote

        func parseHex4(_ start: Int) -> UInt32? {
            guard start + 4 <= end else { return nil }
            var value: UInt32 = 0
            for k in start..<(start + 4) {
                guard let d = chars[k].hexDigitValue else { return nil }
                value = value * 16 + UInt32(d)
            }
            return value
        }

        while i < end {
            let c = chars[i]
            guard c == "\\", i + 1 < end else {
                result.append(c)
                i += 1
                continue
            }
            let esc = chars[i + 1]
            switch esc {
            case "\"": result.append("\""); i += 2
            case "\\": result.append("\\"); i += 2
            case "/":  result.append("/");  i += 2
            case "n":  result.append("\n"); i += 2
            case "t":  result.append("\t"); i += 2
            case "r":  result.append("\r"); i += 2
            case "b":  result.append("\u{08}"); i += 2
            case "f":  result.append("\u{0C}"); i += 2
            case "u":
                guard let hi = parseHex4(i + 2) else {
                    // Malformed \u — keep the backslash and escape char literally and move on.
                    result.append("\\"); result.append(esc); i += 2; continue
                }
                if hi >= 0xD800 && hi <= 0xDBFF {
                    // High surrogate: try to pair with a following \uXXXX low surrogate.
                    if i + 6 < end, chars[i + 6] == "\\", chars[i + 7] == "u",
                       let lo = parseHex4(i + 8), lo >= 0xDC00, lo <= 0xDFFF {
                        let combined = 0x10000 + (hi - 0xD800) * 0x400 + (lo - 0xDC00)
                        if let scalar = Unicode.Scalar(combined) {
                            result.unicodeScalars.append(scalar)
                        }
                        i += 12
                    } else {
                        if let scalar = Unicode.Scalar(hi) {
                            result.unicodeScalars.append(scalar)
                        }
                        i += 6
                    }
                } else if let scalar = Unicode.Scalar(hi) {
                    result.unicodeScalars.append(scalar)
                    i += 6
                } else {
                    // Lone low surrogate / invalid scalar: drop it.
                    i += 6
                }
            default:
                result.append(esc); i += 2
            }
        }
        return result
    }
}

// MARK: - Recursive-descent parser

private struct Parser {
    let chars: [Character]
    var pos: Int = 0

    static let maxDepth = 128

    init(_ text: String) { chars = Array(text) }

    var isAtEnd: Bool { pos >= chars.count }
    var position: Int { pos }

    mutating func skipWhitespace() {
        while pos < chars.count {
            switch chars[pos] {
            case " ", "\t", "\n", "\r": pos += 1
            default: return
            }
        }
    }

    mutating func parseValue(depth: Int) throws -> OrderedJSON {
        skipWhitespace()
        guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
        let c = chars[pos]
        switch c {
        case "{": return try parseObject(depth: depth)
        case "[": return try parseArray(depth: depth)
        case "\"": return .scalar(try parseStringLexeme())
        case "t": return .scalar(try parseLiteral("true"))
        case "f": return .scalar(try parseLiteral("false"))
        case "n": return .scalar(try parseLiteral("null"))
        case "-": return .scalar(try parseNumber())
        default:
            if ("0"..."9").contains(c) { return .scalar(try parseNumber()) }
            throw JSONParseError.unexpectedCharacter(pos)
        }
    }

    mutating func parseObject(depth: Int) throws -> OrderedJSON {
        guard depth < Parser.maxDepth else { throw JSONParseError.tooDeeplyNested(depth) }
        pos += 1 // consume '{'
        var members: [Member] = []
        skipWhitespace()
        if pos < chars.count, chars[pos] == "}" {
            pos += 1
            return .object(members)
        }
        while true {
            skipWhitespace()
            guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
            guard chars[pos] == "\"" else { throw JSONParseError.unexpectedCharacter(pos) }
            let keyLexeme = try parseStringLexeme()
            skipWhitespace()
            guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
            guard chars[pos] == ":" else { throw JSONParseError.unexpectedCharacter(pos) }
            pos += 1 // consume ':'
            let value = try parseValue(depth: depth + 1)
            members.append(Member(keyLexeme: keyLexeme, value: value))
            skipWhitespace()
            guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
            switch chars[pos] {
            case ",": pos += 1
            case "}": pos += 1; return .object(members)
            default: throw JSONParseError.unexpectedCharacter(pos)
            }
        }
    }

    mutating func parseArray(depth: Int) throws -> OrderedJSON {
        guard depth < Parser.maxDepth else { throw JSONParseError.tooDeeplyNested(depth) }
        pos += 1 // consume '['
        var elements: [OrderedJSON] = []
        skipWhitespace()
        if pos < chars.count, chars[pos] == "]" {
            pos += 1
            return .array(elements)
        }
        while true {
            let value = try parseValue(depth: depth + 1)
            elements.append(value)
            skipWhitespace()
            guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
            switch chars[pos] {
            case ",": pos += 1
            case "]": pos += 1; return .array(elements)
            default: throw JSONParseError.unexpectedCharacter(pos)
            }
        }
    }

    /// Captures a string from its opening quote to its closing quote inclusive,
    /// honoring backslash escapes so an escaped quote does not terminate it.
    mutating func parseStringLexeme() throws -> String {
        let start = pos
        pos += 1 // consume opening '"'
        while pos < chars.count {
            let c = chars[pos]
            if c == "\\" {
                pos += 1
                guard pos < chars.count else { throw JSONParseError.unexpectedEnd }
                pos += 1 // skip the escaped char (its tail, e.g. \u hex, is read as normal chars)
            } else if c == "\"" {
                pos += 1 // consume closing '"'
                return String(chars[start..<pos])
            } else {
                pos += 1
            }
        }
        throw JSONParseError.unexpectedEnd
    }

    /// Captures a verbatim JSON number lexeme; throws invalidNumber on malformed input.
    mutating func parseNumber() throws -> String {
        let start = pos
        if pos < chars.count, chars[pos] == "-" { pos += 1 }
        guard pos < chars.count, ("0"..."9").contains(chars[pos]) else {
            throw JSONParseError.invalidNumber(start)
        }
        if chars[pos] == "0" {
            pos += 1
        } else {
            while pos < chars.count, ("0"..."9").contains(chars[pos]) { pos += 1 }
        }
        if pos < chars.count, chars[pos] == "." {
            pos += 1
            guard pos < chars.count, ("0"..."9").contains(chars[pos]) else {
                throw JSONParseError.invalidNumber(start)
            }
            while pos < chars.count, ("0"..."9").contains(chars[pos]) { pos += 1 }
        }
        if pos < chars.count, chars[pos] == "e" || chars[pos] == "E" {
            pos += 1
            if pos < chars.count, chars[pos] == "+" || chars[pos] == "-" { pos += 1 }
            guard pos < chars.count, ("0"..."9").contains(chars[pos]) else {
                throw JSONParseError.invalidNumber(start)
            }
            while pos < chars.count, ("0"..."9").contains(chars[pos]) { pos += 1 }
        }
        return String(chars[start..<pos])
    }

    mutating func parseLiteral(_ literal: String) throws -> String {
        let lit = Array(literal)
        guard pos + lit.count <= chars.count else { throw JSONParseError.unexpectedEnd }
        for k in 0..<lit.count where chars[pos + k] != lit[k] {
            throw JSONParseError.unexpectedCharacter(pos)
        }
        pos += lit.count
        return literal
    }
}
