import Foundation

/// The player-economy values the editor can change. `rawValue` doubles as the
/// stable `id` and as the dictionary key the model uses for its load-time snapshot.
/// Research Point is a spendable resource that behaves exactly like a currency
/// (single value + clamp + "Set to Max"), so it rides the same row machinery.
enum Currency: String, CaseIterable, Identifiable {
    case gold, bei, artisansFlame, followerCount, researchPoint

    var id: String { rawValue }

    /// Human-readable label shown beside each field.
    var label: String {
        switch self {
        case .gold:          return "Gold"
        case .bei:           return "Bei"
        case .artisansFlame: return "Artisan's Flame"
        case .followerCount: return "Follower Count"
        case .researchPoint: return "Research Point"
        }
    }

    /// SF Symbol shown on the value card.
    var systemImage: String {
        switch self {
        case .gold:          return "dollarsign.circle.fill"
        case .bei:           return "fish.fill"
        case .artisansFlame: return "flame.fill"
        case .followerCount: return "person.2.fill"
        case .researchPoint: return "flask.fill"
        }
    }

    /// Value applied by the per-currency "Set to Max" button. This is the *button*
    /// preset, not the engine clamp: gold/bei present the full 999,999,999 clamp,
    /// flame's button stops at 999,999, and follower (unclamped) at 99,999.
    var maxButtonValue: Int64 {
        switch self {
        case .gold:          return 999_999_999
        case .bei:           return 999_999_999
        case .artisansFlame: return 999_999
        case .followerCount: return 99_999
        case .researchPoint: return 999_999_999
        }
    }
}
