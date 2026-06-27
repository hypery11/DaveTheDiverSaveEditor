import Testing
import Foundation
@testable import DaveSaveCore

@Suite struct SaveCodecTests {

    // (a) Hand-computed tiny vector — plaintext "ab" XOR key "GameData":
    //     'a'(0x61) ^ 'G'(0x47) = 0x26 ; 'b'(0x62) ^ 'a'(0x61) = 0x03.
    @Test func handVectorEncode() {
        #expect(SaveCodec.encode("ab") == Data([0x26, 0x03]))
    }

    @Test func handVectorDecode() {
        #expect(SaveCodec.decode(Data([0x26, 0x03])) == "ab")
    }

    // key16 is exactly the ASCII code units of "GameData".
    @Test func keyIsGameDataCodeUnits() {
        #expect(Array("GameData".utf16) == [0x47, 0x61, 0x6D, 0x65, 0x44, 0x61, 0x74, 0x61])
    }

    // (b) Round-trip on a JSON-ish fixture. A real `.sav` is by definition an
    //     `encode()` output, so build one from a compact plaintext, then assert
    //     encode(decode(x)) == x byte-for-byte AND decode recovers the plaintext.
    @Test func roundTripIsByteIdentical() {
        let plaintext = #"{"PlayerInfo":{"m_Gold":999999999,"m_Bei":12345,"m_ChefFlame":67890},"SNSInfo":{"m_Follow_Count":42}}"#
        let sav = SaveCodec.encode(plaintext)
        #expect(SaveCodec.encode(SaveCodec.decode(sav)) == sav)
        #expect(SaveCodec.decode(sav) == plaintext)
    }

    // (d) Discriminating test: verifies that encode produces per-UTF-16-code-unit
    //     XOR bytes, not byte-level XOR bytes.
    //     白 = U+767D (UTF-16 code unit 0x767D). key16[0] = 'G' = 0x47.
    //     0x767D ^ 0x0047 = 0x763A (U+763A), whose UTF-8 encoding is [0xE7, 0x98, 0xBA].
    //     A byte-level XOR would produce [0xA0, 0xF8, 0xD0] and fail this test.
    @Test func encodeCJKProducesCodeUnitXorBytesNotByteXor() {
        #expect(SaveCodec.encode("白") == Data([0xE7, 0x98, 0xBA]))
        #expect(SaveCodec.decode(Data([0xE7, 0x98, 0xBA])) == "白")
    }

    // (c) CJK round-trip with ZERO U+FFFD, on a farm animal whose id is NOT
    //     11090001 (the exact case upstream silently corrupts).
    @Test func cjkRoundTripHasNoReplacementChar() {
        let plaintext = #"{"FarmAnimal":[{"FarmAnimalID":11090002,"Name":"白毛鸡"}]}"#
        let sav = SaveCodec.encode(plaintext)
        let decoded = SaveCodec.decode(sav)
        #expect(decoded == plaintext)
        #expect(!decoded.unicodeScalars.contains("\u{FFFD}"))
        #expect(SaveCodec.encode(decoded) == sav)
    }
}
