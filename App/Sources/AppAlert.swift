import Foundation

/// A value-type alert the model surfaces to SwiftUI views via `alert`.
struct AppAlert: Identifiable, Equatable {
    let id: UUID
    let title: String
    let message: String
    var revealURL: URL?
}
