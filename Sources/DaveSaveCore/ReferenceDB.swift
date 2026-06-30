import Foundation
import SQLite3

public struct IngredientRow: Equatable {
    public let id: Int
    public let parentID: Int
    public let maxCount: Int
    public let dlcType: Int
    public init(id: Int, parentID: Int, maxCount: Int, dlcType: Int) {
        self.id = id
        self.parentID = parentID
        self.maxCount = maxCount
        self.dlcType = dlcType
    }
}

/// A craftable material (ItemType 6: fish parts, DREDGE research parts / bones / eyes …).
/// `id` is `Items.TID` — the value the save's `InventoryItemSlot.itemID` uses for these
/// (their `ItemDataID` is -1). `dlcType` gates injection by installed DLC.
public struct CraftMaterialRow: Equatable {
    public let id: Int
    public let dlcType: Int
    public init(id: Int, dlcType: Int) {
        self.id = id
        self.dlcType = dlcType
    }
}

public enum ReferenceDBError: Error, Equatable {
    case cannotOpen(code: Int32)
    case missingBundleResource
}

// SAFETY: @unchecked Sendable is sound here because:
//   1. The SQLite handle is opened SQLITE_OPEN_READONLY — no writes are possible.
//   2. Apple's system SQLite defaults to serialized threading mode (SQLITE_THREADSAFE=1),
//      so concurrent calls from multiple threads are internally serialised.
//   3. The only mutable state (stmt) is allocated, stepped, and finalised within
//      each method call — it is never stored on self, so there is no shared mutable state.
public final class ReferenceDB: @unchecked Sendable {
    private let db: OpaquePointer

    /// Opens the database read-only (`SQLITE_OPEN_READONLY`); throws if the file
    /// is missing or cannot be opened.
    public init(url: URL) throws {
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, let handle else {
            sqlite3_close(handle)
            throw ReferenceDBError.cannotOpen(code: rc)
        }
        self.db = handle
    }

    /// Opens the `reference.sqlite` shipped as a `Bundle.module` resource.
    public static func bundled() throws -> ReferenceDB {
        guard let url = Bundle.module.url(forResource: "reference", withExtension: "sqlite") else {
            throw ReferenceDBError.missingBundleResource
        }
        return try ReferenceDB(url: url)
    }

    deinit { sqlite3_close(db) }

    /// `SELECT MaxCount FROM Items WHERE ItemDataID = ?` — nil if no such item.
    public func maxCount(itemDataID: Int) -> Int? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT MaxCount FROM Items WHERE ItemDataID = ?;", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(itemDataID))
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    /// `SELECT I.TID, T.TID, T.MaxCount, T.DLCType FROM Ingredients I
    ///  JOIN Items T ON I.TID = T.ItemDataID` — parentID is the matched Items.TID.
    public func allIngredients() -> [IngredientRow] {
        var rows: [IngredientRow] = []
        var stmt: OpaquePointer?
        let sql = "SELECT I.TID, T.TID, T.MaxCount, T.DLCType FROM Ingredients I JOIN Items T ON I.TID = T.ItemDataID;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return rows }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(IngredientRow(
                id: Int(sqlite3_column_int64(stmt, 0)),
                parentID: Int(sqlite3_column_int64(stmt, 1)),
                maxCount: Int(sqlite3_column_int64(stmt, 2)),
                dlcType: Int(sqlite3_column_int64(stmt, 3))
            ))
        }
        return rows
    }

    /// `SELECT TID, DLCType FROM Items WHERE ItemType = 6` — the craft materials
    /// (fish parts, DREDGE research parts / bones). Unlike raw aberration fish these
    /// are NOT perishable, so they are safe to inject and stock.
    public func craftMaterials() -> [CraftMaterialRow] {
        var rows: [CraftMaterialRow] = []
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT TID, DLCType FROM Items WHERE ItemType = 6;", -1, &stmt, nil) == SQLITE_OK else {
            return rows
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(CraftMaterialRow(
                id: Int(sqlite3_column_int64(stmt, 0)),
                dlcType: Int(sqlite3_column_int64(stmt, 1))
            ))
        }
        return rows
    }
}
