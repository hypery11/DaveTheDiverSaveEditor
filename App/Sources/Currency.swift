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
        case .gold:          return String(localized: "Gold")
        case .bei:           return String(localized: "Bei")
        case .artisansFlame: return String(localized: "Artisan's Flame")
        case .followerCount: return String(localized: "Follower Count")
        case .researchPoint: return String(localized: "Research Point")
        case .trustPoint:    return String(localized: "Credit")
        case .fakePoint:     return String(localized: "Fake Point")
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
        case .gold:          return String(localized: "Main restaurant & shop currency")
        case .bei:           return String(localized: "Sea People Village currency")
        case .artisansFlame: return String(localized: "Weapon-upgrade currency")
        case .followerCount: return String(localized: "Cooksta followers — a progression stat")
        case .researchPoint: return String(localized: "Spent on research & recipes")
        case .trustPoint:    return String(localized: "PlayerInfo.m_trustPoint — Sea People Village trust, shown in-game as “Credit”")
        case .fakePoint:     return String(localized: "PlayerInfo.m_FakePoint — fake / counterfeit points")
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
        // Both read 100 in a mid/late-game real save, so their in-game domain is likely
        // small + unverified — keep the "Set to Max" preset conservative (Set exact still
        // allows any value; the engine clamps at 999,999,999 either way).
        case .trustPoint:    return 9_999
        case .fakePoint:     return 9_999
        }
    }
}
