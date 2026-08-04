// App/Sources/SnapshotMode.swift
import AppKit

/// Seam used by `scripts/screenshots.sh` to produce the marketing screenshots.
/// Every value is unset on a normal launch, so this is inert at runtime.
///
/// Read through `UserDefaults` rather than `ProcessInfo.arguments` on purpose: the
/// script sets these with `defaults write` and then launches the app through
/// LaunchServices with **no arguments**. Passing them as launch arguments instead
/// prevented the `WindowGroup` from ever creating a window, and `defaults` also gives
/// us `AppleLanguages` — the only reliable way to force the language for
/// `String(localized:)`, which ignores SwiftUI's environment locale.
enum Snapshot {
    /// Fixed content size so every locale x appearance PNG comes out the same size —
    /// otherwise Korean and Chinese string lengths give the set different widths.
    static var contentSize: CGSize? {
        let w = UserDefaults.standard.double(forKey: "SnapshotWidth"), h = UserDefaults.standard.double(forKey: "SnapshotHeight")
        return (w > 0 && h > 0) ? CGSize(width: w, height: h) : nil
    }

    /// Preload a save so the capture shows populated rows.
    static var fixture: String? { UserDefaults.standard.string(forKey: "SnapshotFixture") }

    /// Open a sheet for its own screenshot: `raw` | `backups` | `preview`.
    static var sheet: String? { UserDefaults.standard.string(forKey: "SnapshotSheet") }

    /// `dark` | `light`. Applied to `NSApp.appearance` rather than
    /// `.preferredColorScheme` so the title bar and traffic lights are themed too.
    /// Called once the window exists — touching `NSApplication.shared` from
    /// `App.init()` stops the `WindowGroup` creating a window at all.
    @MainActor static func applyAppearance() {
        switch UserDefaults.standard.string(forKey: "SnapshotAppearance") {
        case "dark":  NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
        default:      break
        }
    }
}
