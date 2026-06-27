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

public enum ReferenceDBError: Error, Equatable {
    case cannotOpen(code: Int32)
    case missingBundleResource
}

public final class ReferenceDB {
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
}
