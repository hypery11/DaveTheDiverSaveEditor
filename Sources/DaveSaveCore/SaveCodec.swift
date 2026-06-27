import Foundation

/// Char-level (UTF-16 code-unit) XOR codec mirroring the game's own algorithm.
///
/// The on-disk `.sav` is the UTF-8 encoding of the per-code-unit-XOR'd JSON
/// string. The key `"GameData"` is ASCII (all code units < 0x80) and cycles
/// once per UTF-16 code unit. Both directions are pure and perform no I/O;
/// by construction `encode(decode(x)) == x` byte-for-byte for any save the
/// game itself produced (valid UTF-8), and CJK content survives losslessly.
///
/// - Note: This codec assumes **BMP-only** content (Unicode code points U+0000
///   through U+FFFF, no supplementary/astral characters or surrogate pairs).
///   Dave the Diver saves contain only BMP characters, so this constraint holds
///   in practice. XOR-ing a surrogate half (U+D800–U+DFFF) would produce an
///   invalid code unit and yield U+FFFD on re-decode.
public enum SaveCodec {
    /// XOR key code units: `Array("GameData".utf16)`
    /// == [0x47, 0x61, 0x6D, 0x65, 0x44, 0x61, 0x74, 0x61].
    private static let key16: [UInt16] = Array("GameData".utf16)

    /// `.sav` bytes -> JSON text.
    public static func decode(_ data: Data) -> String {
        let encStr = String(decoding: data, as: UTF8.self)
        var units = Array(encStr.utf16)
        let keyCount = key16.count
        for i in units.indices {
            units[i] ^= key16[i % keyCount]
        }
        return String(decoding: units, as: UTF16.self)
    }

    /// JSON text -> `.sav` bytes.
    public static func encode(_ json: String) -> Data {
        var units = Array(json.utf16)
        let keyCount = key16.count
        for i in units.indices {
            units[i] ^= key16[i % keyCount]
        }
        return Data(String(decoding: units, as: UTF16.self).utf8)
    }
}
