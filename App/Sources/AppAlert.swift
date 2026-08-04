import Foundation

/// A value-type alert the model surfaces to SwiftUI views via `alert`.
struct AppAlert: Identifiable, Equatable {
    /// What kind of outcome this alert reports. Callers switch on this rather than comparing
    /// `title`, which is localized and would silently stop matching in any other language.
    enum Kind { case info, writeSucceeded, failure }

    let id: UUID
    var kind: Kind = .info
    let title: String
    let message: String
    var revealURL: URL?
}
