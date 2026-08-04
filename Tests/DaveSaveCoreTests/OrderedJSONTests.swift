import Testing
import Foundation
import DaveSaveCore

// Synthetic/anonymized fixtures only. Compact JSON (no whitespace), matching the
// game's on-disk style: nested objects/arrays, a >2^53 big-int (LastUpdateTime-like),
// CJK key+value, an escaped quote, negative/float/bool/null, and empty containers.
private let compactFixture =
#"{"PlayerInfo":{"m_Gold":999999999,"m_Bei":-5,"ratio":3.14,"flag":true,"none":null},"LastUpdateTime":639076164000175857,"名前":"白毛鸡","quote":"a\"b\\c","arr":[1,2,{"x":"y"}],"empty":{},"emptyArr":[]}"#

@Suite struct OrderedJSONTests {

    @Test func noOpRoundTripIsByteIdentical() throws {
        let dom = try OrderedJSON.parse(compactFixture)
        #expect(dom.serialized() == compactFixture)
    }

    @Test func bigIntScalarIsPreservedVerbatim() throws {
        let dom = try OrderedJSON.parse(compactFixture)
        guard case .object(let members) = dom,
              let m = members.first(where: { $0.key == "LastUpdateTime" }) else {
            Issue.record("LastUpdateTime member missing"); return
        }
        #expect(m.value == .scalar("639076164000175857"))
    }

    @Test func scalarStringLexemesIncludeQuotesAndEscapes() throws {
        let dom = try OrderedJSON.parse(compactFixture)
        guard case .object(let members) = dom else { Issue.record("not object"); return }
        let name = members.first { $0.key == "名前" }
        #expect(name?.value == .scalar(#""白毛鸡""#))
        let quote = members.first { $0.key == "quote" }
        #expect(quote?.value == .scalar(#""a\"b\\c""#))   // verbatim, escapes intact
    }

    @Test func memberKeyDecodesQuotesAndEscapes() throws {
        let dom = try OrderedJSON.parse(#"{"ABC":1,"a\"b":2,"白":3}"#)
        guard case .object(let members) = dom else { Issue.record("not object"); return }
        #expect(members[0].keyLexeme == #""ABC""#) // verbatim lexeme keeps the escape
        #expect(members[0].key == "ABC")                // decoded: A -> A
        #expect(members[1].key == "a\"b")               // decoded: \" -> "
        #expect(members[2].key == "白")
    }

    @Test func emptyContainersRoundTrip() throws {
        #expect(try OrderedJSON.parse("{}").serialized() == "{}")
        #expect(try OrderedJSON.parse("[]").serialized() == "[]")
    }

    @Test func malformedInputsThrowTypedErrors() {
        #expect(throws: JSONParseError.unexpectedEnd) { _ = try OrderedJSON.parse("") }
        #expect(throws: JSONParseError.unexpectedEnd) { _ = try OrderedJSON.parse("tru") }
        #expect(throws: JSONParseError.unexpectedCharacter(5)) { _ = try OrderedJSON.parse("{\"a\":}") }
        #expect(throws: JSONParseError.unexpectedCharacter(2)) { _ = try OrderedJSON.parse("{}x") } // trailing garbage
        #expect(throws: JSONParseError.invalidNumber(0)) { _ = try OrderedJSON.parse("12.") } // bad number
    }

    @Test func deeplyNestedInputThrowsTooDeeplyNested() {
        // Build a 200-deep nested array; the parser must throw tooDeeplyNested
        // (at depth 128) rather than overflowing the call stack and crashing.
        let input = String(repeating: "[", count: 200) + "1" + String(repeating: "]", count: 200)
        var caught: JSONParseError?
        do {
            _ = try OrderedJSON.parse(input)
        } catch let e as JSONParseError {
            caught = e
        } catch {}
        guard case .tooDeeplyNested = caught else {
            Issue.record("Expected .tooDeeplyNested, got \(String(describing: caught))")
            return
        }
    }

    @Test func realSaveParsesAndReserializesByteIdentical() throws {
        // Optional local fixture (gitignored LocalFixtures/, never committed; skipped in CI if absent).
        let url = URL(fileURLWithPath:
            "/Volumes/OWC Envoy Ultra/dave-the-diver-save-editor/LocalFixtures/real_sample_GD.sav")
        guard let raw = try? Data(contentsOf: url) else { return }   // skip-if-absent
        let json = SaveCodec.decode(raw)
        let dom = try OrderedJSON.parse(json)
        #expect(dom.serialized() == json)               // no-op byte-identity on REAL data
        #expect(SaveCodec.encode(dom.serialized()) == raw)  // full pipeline byte-identical
    }
}
