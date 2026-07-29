// App/Sources/Diagnostics.swift
import AppKit
import Foundation

/// Builds a paste-ready diagnostics block for the Help ▸ Copy Diagnostics command.
///
/// Most people who hit a problem with this app are not on GitHub — they're on Nexus,
/// Bilibili, 3DM or DC Inside, and many won't be writing in English. A block they can
/// paste anywhere turns "it didn't work" into something actionable regardless of where
/// they report it or what language they report it in.
///
/// Deliberately contains no save contents and no full paths: only the save's file name
/// and which known location it came from. Nothing is transmitted — this copies to the
/// clipboard and that is all.
enum Diagnostics {

    @MainActor
    static func text(for model: SaveEditorModel) -> String {
        var lines: [String] = []
        lines.append("DiveSaveEd \(AppInfo.version) (build \(AppInfo.build))")
        lines.append("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("Architecture: \(architecture)")
        lines.append("App language: \(Locale.preferredLanguages.first ?? "unknown")")
        lines.append("Save loaded: \(model.isLoaded ? "yes" : "no")")
        if let url = model.currentFileURL {
            lines.append("Save file: \(url.lastPathComponent)")
            lines.append("Save location: \(locationLabel(for: url))")
        }
        lines.append("Save slots detected: \(model.availableSaves().count)")
        if !model.ingredientStatus.isEmpty {
            lines.append("Last action: \(model.ingredientStatus)")
        }
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func copyToPasteboard(for model: SaveEditorModel) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text(for: model), forType: .string)
    }

    /// Which of the known save roots this file sits under — useful because the two
    /// layouts are the most common source of "it can't find my save" reports. Reported
    /// as a label rather than a path so no user name is included.
    private static func locationLabel(for url: URL) -> String {
        let path = url.path
        if path.contains("com.nexon.dave") { return "com.nexon.dave (Steam)" }
        if path.contains("DAVE THE DIVER")  { return "nexon/DAVE THE DIVER (Steam)" }
        return "other (opened manually)"
    }

    private static var architecture: String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        // Report translation too: an Intel build under Rosetta behaves differently.
        var ret = Int32(0), size = MemoryLayout<Int32>.size
        if sysctlbyname("sysctl.proc_translated", &ret, &size, nil, 0) == 0, ret == 1 {
            return "Intel binary under Rosetta"
        }
        return "Intel"
        #else
        return "unknown"
        #endif
    }
}
