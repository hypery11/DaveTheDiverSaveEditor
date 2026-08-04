// App/Sources/SupportAsk.swift
import Foundation

/// Why the support prompt is being shown.
enum SupportPromptKind: Identifiable {
    case launch
    case afterWrites(Int)

    var id: String {
        switch self {
        case .launch: return "launch"
        case .afterWrites(let n): return "writes-\(n)"
        }
    }
}

/// Decides when to show the support prompt, and counts writes so it can recur.
///
/// Note on what this stores, because it changed and the change is worth being explicit about:
/// an earlier version deliberately kept **no** usage data, only whether the prompt had been
/// shown. Recurring every N writes cannot be done without counting writes, so the write total
/// is now persisted. It stays local (`UserDefaults`, app container, never transmitted — the app
/// makes no network requests), it is a bare integer with no timestamps and no per-save detail,
/// and `README`/`SECURITY.md` say so. But it is usage data where there was none before.
enum SupportAsk {
    static let writeCountKey = "SupportAskWriteCount"

    /// Prompt on every launch, and after every third successful write.
    static let writeInterval = 3

    /// Always due at launch, in every language.
    static var isDueAtLaunch: Bool {
        // Never during a screenshot run or a UI test, or captures stop being reproducible.
        Snapshot.fixture == nil && Snapshot.sheet == nil
    }

    /// Record a successful write; returns the running total when the prompt is due.
    static func registerWriteAndCheck() -> Int? {
        guard Snapshot.fixture == nil, Snapshot.sheet == nil else { return nil }
        let total = UserDefaults.standard.integer(forKey: writeCountKey) + 1
        UserDefaults.standard.set(total, forKey: writeCountKey)
        return total % writeInterval == 0 ? total : nil
    }

    /// Test seam.
    static func resetWriteCount() {
        UserDefaults.standard.removeObject(forKey: writeCountKey)
    }
}
