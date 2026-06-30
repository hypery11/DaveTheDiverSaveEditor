import Foundation
import SQLite3

enum TestSupportError: Error { case cannotCreate(Int32); case exec(String) }

/// Builds a minimal `reference.sqlite`-shaped database at `url`.
/// Rows mirror real game data so they double as documentation:
///   ItemDataID 1020201 -> MaxCount 9999 (tier 6666), DLCType 1 (DREDGE aberration; perishable -> never maxed)
///   ItemDataID 1021006 -> MaxCount 9999 (tier 6666), DLCType 0 (base; the normal "maxed to 6666" fixture)
///   ItemDataID 1021011 -> MaxCount 99   (tier 66),   DLCType 0 (base)
///   ItemDataID 1025901 -> MaxCount 1    (tier skip), DLCType 0 (base)
///   ItemDataID 1027019 -> MaxCount 9999 (tier 6666), DLCType 5 (Godzilla)
/// `Items.TID` is the primary key returned as `parentID` by the join.
func makeTinyReferenceDB(at url: URL) throws {
    try? FileManager.default.removeItem(at: url)
    var handle: OpaquePointer?
    let rc = sqlite3_open(url.path, &handle)
    guard rc == SQLITE_OK, let handle else {
        sqlite3_close(handle)
        throw TestSupportError.cannotCreate(rc)
    }
    defer { sqlite3_close(handle) }
    // ItemType mirrors the real DB: 4 = ingredient/fish, 6 = craft material (fish parts,
    // DREDGE research parts/bones — keyed in the save by Items.TID, ItemDataID is -1).
    let sql = """
    CREATE TABLE Items (
        TID INTEGER PRIMARY KEY,
        ItemDataID INTEGER NOT NULL,
        MaxCount INTEGER NOT NULL,
        DLCType INTEGER NOT NULL,
        ItemType INTEGER NOT NULL
    );
    CREATE TABLE Ingredients (
        TID INTEGER PRIMARY KEY,
        Type INTEGER NOT NULL
    );
    INSERT INTO Items VALUES (1010201, 1020201, 9999, 1, 4);
    INSERT INTO Items VALUES (1011006, 1021006, 9999, 0, 4);
    INSERT INTO Items VALUES (1011701, 1021011, 99,   0, 4);
    INSERT INTO Items VALUES (1018901, 1025901, 1,    0, 4);
    INSERT INTO Items VALUES (1017019, 1027019, 9999, 5, 4);
    INSERT INTO Items VALUES (1014980, -1,      9999, 1, 6);  -- DREDGE research part (DLC-gated)
    INSERT INTO Items VALUES (1018090, -1,      9999, 0, 6);  -- base craft material (always)
    INSERT INTO Ingredients VALUES (1020201, 0);
    INSERT INTO Ingredients VALUES (1021011, 0);
    INSERT INTO Ingredients VALUES (1025901, 0);
    INSERT INTO Ingredients VALUES (1027019, 0);
    INSERT INTO Ingredients VALUES (1021006, 0);
    """
    var errMsg: UnsafeMutablePointer<CChar>?
    guard sqlite3_exec(handle, sql, nil, nil, &errMsg) == SQLITE_OK else {
        let msg = errMsg.map { String(cString: $0) } ?? "unknown"
        sqlite3_free(errMsg)
        throw TestSupportError.exec(msg)
    }
}
