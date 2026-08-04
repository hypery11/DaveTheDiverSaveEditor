import Testing
@testable import DaveSaveCore

@Suite struct PrettyPrintTests {
    @Test func prettyPrintIsIndentedLosslessAndOrdered() throws {
        let compact = #"{"b":{"x":[1,2,3],"y":"hi","e":{}},"a":true,"z":[]}"#
        let tree = try OrderedJSON.parse(compact)
        let pretty = tree.prettyPrinted()

        #expect(pretty.contains("\n"))                                   // actually indented
        #expect(pretty.contains("[]") && pretty.contains("{}"))          // empties stay inline
        #expect(try OrderedJSON.parse(pretty).serialized() == compact)   // lossless round-trip
        // member order preserved: b before a before z
        let bIdx = pretty.range(of: #""b""#)!.lowerBound
        let aIdx = pretty.range(of: #""a""#)!.lowerBound
        let zIdx = pretty.range(of: #""z""#)!.lowerBound
        #expect(bIdx < aIdx && aIdx < zIdx)
    }
}
