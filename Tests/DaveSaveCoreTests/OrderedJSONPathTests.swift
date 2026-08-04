import Testing
import DaveSaveCore

// Synthetic fixture mirroring the real editable paths (PlayerInfo.*, Ingredients.<id>.count),
// including a non-11090001 farm-animal ingredient id to match the project's fixture policy.
private let base =
#"{"PlayerInfo":{"m_Gold":100,"m_Bei":200},"Ingredients":{"14090007":{"count":5}}}"#

@Suite struct OrderedJSONPathTests {

    @Test func readsNestedScalarByDecodedKeyPath() throws {
        let dom = try OrderedJSON.parse(base)
        #expect(dom.value(at: ["PlayerInfo", "m_Gold"]) == .scalar("100"))
        #expect(dom.value(at: ["Ingredients", "14090007", "count"]) == .scalar("5"))
        #expect(dom.value(at: []) == dom)                       // empty path == self
        #expect(dom.value(at: ["PlayerInfo", "missing"]) == nil) // missing key
        #expect(dom.value(at: ["PlayerInfo", "m_Gold", "x"]) == nil) // descend into scalar
    }

    @Test func setScalarChangesOnlyTheTargetLexeme() throws {
        var dom = try OrderedJSON.parse(base)
        #expect(dom.setScalar(at: ["PlayerInfo", "m_Gold"], lexeme: "999999999") == true)
        #expect(dom.serialized() ==
            #"{"PlayerInfo":{"m_Gold":999999999,"m_Bei":200},"Ingredients":{"14090007":{"count":5}}}"#)
    }

    @Test func setScalarRejectsMissingOrNonScalarTargets() throws {
        var dom = try OrderedJSON.parse(base)
        #expect(dom.setScalar(at: ["PlayerInfo", "missing"], lexeme: "1") == false)
        #expect(dom.setScalar(at: ["PlayerInfo"], lexeme: "1") == false) // target is an object
        #expect(dom.serialized() == base)                                // unchanged on failure
    }

    @Test func setMemberAppendsNewMemberInOrder() throws {
        var dom = try OrderedJSON.parse(base)
        let injected = Member(keyLexeme: #""14010001""#, value: try OrderedJSON.parse(#"{"count":66}"#))
        #expect(dom.setMember(at: ["Ingredients"], member: injected) == true)
        #expect(dom.serialized() ==
            #"{"PlayerInfo":{"m_Gold":100,"m_Bei":200},"Ingredients":{"14090007":{"count":5},"14010001":{"count":66}}}"#)
    }

    @Test func setMemberReplacesExistingMemberInPlace() throws {
        var dom = try OrderedJSON.parse(base)
        let replacement = Member(keyLexeme: #""14090007""#, value: try OrderedJSON.parse(#"{"count":6666}"#))
        #expect(dom.setMember(at: ["Ingredients"], member: replacement) == true)
        #expect(dom.serialized() ==
            #"{"PlayerInfo":{"m_Gold":100,"m_Bei":200},"Ingredients":{"14090007":{"count":6666}}}"#)
    }

    @Test func setMemberFailsWhenPathIsNotAnObject() throws {
        var dom = try OrderedJSON.parse(base)
        let m = Member(keyLexeme: #""z""#, value: .scalar("1"))
        #expect(dom.setMember(at: ["PlayerInfo", "m_Gold"], member: m) == false) // path ends at scalar
        #expect(dom.setMember(at: ["nope"], member: m) == false)                 // missing path
        #expect(dom.serialized() == base)
    }
}
