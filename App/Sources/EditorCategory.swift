// App/Sources/EditorCategory.swift
import SwiftUI

/// The sidebar categories. Order here is the sidebar order. (Farm's single "Max Seeds"
/// action was folded into Inventory to avoid a one-card top-level pane.)
enum EditorCategory: String, CaseIterable, Identifiable {
    case economy, restaurant, inventory, advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .economy:    return String(localized: "Economy")
        case .restaurant: return String(localized: "Restaurant")
        case .inventory:  return String(localized: "Inventory")
        case .advanced:   return String(localized: "Advanced")
        }
    }

    var systemImage: String {
        switch self {
        case .economy:    return "dollarsign.circle.fill"
        case .restaurant: return "fork.knife"
        case .inventory:  return "shippingbox.fill"
        case .advanced:   return "wrench.and.screwdriver.fill"
        }
    }

    var accent: Color {
        switch self {
        case .economy:    return Theme.Color.goldGlyph
        case .restaurant: return Theme.Color.coral
        case .inventory:  return Theme.Color.ocean
        case .advanced:   return Theme.Color.slate
        }
    }
}
