// App/Sources/EditorCategory.swift
import SwiftUI

/// The sidebar categories. Order here is the sidebar order.
enum EditorCategory: String, CaseIterable, Identifiable {
    case economy, restaurant, farm, inventory, advanced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .economy:    return "Economy"
        case .restaurant: return "Restaurant"
        case .farm:       return "Farm"
        case .inventory:  return "Inventory"
        case .advanced:   return "Advanced"
        }
    }

    var systemImage: String {
        switch self {
        case .economy:    return "dollarsign.circle.fill"
        case .restaurant: return "fork.knife"
        case .farm:       return "leaf.fill"
        case .inventory:  return "shippingbox.fill"
        case .advanced:   return "wrench.and.screwdriver.fill"
        }
    }

    var accent: Color {
        switch self {
        case .economy:    return Theme.Color.gold
        case .restaurant: return Theme.Color.coral
        case .farm:       return Theme.Color.leaf
        case .inventory:  return Theme.Color.ocean
        case .advanced:   return Theme.Color.slate
        }
    }
}
