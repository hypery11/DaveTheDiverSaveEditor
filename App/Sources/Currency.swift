import Foundation

/// The player-economy values the editor can change. `rawValue` doubles as the
/// stable `id` and as the dictionary key the model uses for its load-time snapshot.
/// Research Point is a spendable resource that behaves exactly like a currency
/// (single value + clamp + "Set to Max"), so it rides the same row machinery.
enum Currency: String, CaseIterable, Identifiable {
    case gold, bei, artisansFlame, followerCount, researchPoint, trustPoint, fakePoint

    var id: String { rawValue }

    /// Human-readable label shown beside each field.
    var label: String {
        switch self {
        case .gold:          return "Gold"
        case .bei:           return "Bei"
        case .artisansFlame: return "Artisan's Flame"
        case .followerCount: return "Follower Count"
        case .researchPoint: return "Research Point"
        case .trustPoint:    return "Trust Point"
        case .fakePoint:     return "Fake Point"
        }
    }

    /// SF Symbol shown on the value card.
    var systemImage: String {
        switch self {
        case .gold:          return "dollarsign.circle.fill"
        case .bei:           return "diamond.fill"       // Sea People currency, not a fish
        case .artisansFlame: return "flame.fill"
        case .followerCount: return "person.2.fill"
        case .researchPoint: return "flask.fill"
        case .trustPoint:    return "checkmark.seal.fill"
        case .fakePoint:     return "theatermasks.fill"
        }
    }

    /// One-line explainer under the label (what it is / where it's spent).
    var caption: String {
        switch self {
        case .gold:          return "Main restaurant & shop currency"
        case .bei:           return "Sea People (Merman Village) currency"
        case .artisansFlame: return "Weapon-upgrade currency"
        case .followerCount: return "Cooksta followers — a progression stat"
        case .researchPoint: return "Spent on research & recipes"
        case .trustPoint:    return "PlayerInfo.m_trustPoint — villager trust points"
        case .fakePoint:     return "PlayerInfo.m_FakePoint — fake / counterfeit points"
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
        case .trustPoint:    return 999_999
        case .fakePoint:     return 999_999
        }
    }
}
