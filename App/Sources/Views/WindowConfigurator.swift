// App/Sources/Views/WindowConfigurator.swift
import SwiftUI
import AppKit

/// Reaches the hosting `NSWindow` to do three things SwiftUI has no API for.
///
/// 1. **Clear the initial first responder.** macOS hands it to the first `TextField` in the
///    window — the Gold row's exact-value field — so on a freshly opened save, typing "5" and
///    pressing Return silently set Gold to 5. A zero-size `.focusable()` sink plus
///    `.defaultFocus` does *not* fix this; it was tried and the focus ring stayed on Gold.
/// 2. **`isDocumentEdited`**, which gives the standard dot in the close button and the
///    warning on quit, free. This app never autosaves, so that signal is load-bearing.
/// 3. **`representedURL`**, which gives the proxy icon, ⌘-click-for-path, and drag-out.
struct WindowConfigurator: NSViewRepresentable {
    var isEdited: Bool
    var representedURL: URL?

    final class Coordinator { var clearedFocus = false }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        // The window isn't attached during the first layout pass, and clearing focus has to
        // happen after SwiftUI has installed its own responder or it is simply overwritten.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isDocumentEdited = isEdited
            window.representedURL = representedURL
            if !context.coordinator.clearedFocus {
                context.coordinator.clearedFocus = true
                window.makeFirstResponder(nil)
            }
        }
    }
}
