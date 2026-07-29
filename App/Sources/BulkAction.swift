// App/Sources/BulkAction.swift
import SwiftUI
import DaveSaveCore

/// One bulk "max/fill" operation, described as data. This is the single source the
/// UI rows, "Max Everything", and the model's named entry points all derive from —
/// so the op's definition can't drift across those three call sites.
///
/// All user-facing text here goes through `String(localized:)`, so every title,
/// description, button label and status line lands in the String Catalog.
struct BulkAction: Identifiable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let description: String
    let accent: Color
    let buttonTitle: String
    let section: EditorCategory          // which pane's section renders it
    let includeInMaxEverything: Bool
    /// Mutate the document; return a status string, or nil if it couldn't run
    /// (e.g. an ingredient op with no reference DB) so callers can skip it.
    /// `@Sendable` (the closures capture nothing) so the static `catalog` is safe.
    let run: @Sendable (inout SaveDocument, ReferenceDB?) -> String?

    static func with(id: String) -> BulkAction {
        guard let a = catalog.first(where: { $0.id == id }) else {
            preconditionFailure("unknown BulkAction id: \(id)")   // developer-facing, not localized
        }
        return a
    }

    static let catalog: [BulkAction] = [
        // — Restaurant —
        BulkAction(id: "maxOwn", title: String(localized: "Max Owned Ingredients"), systemImage: "tray.full.fill",
                   description: String(localized: "Fill every ingredient you already own (skips perishable aberration fish)."),
                   accent: Theme.Color.coral, buttonTitle: String(localized: "Max Own"), section: .restaurant,
                   includeInMaxEverything: false) { doc, ref in           // superseded by Max All in Max Everything
            guard let ref else { return nil }
            doc.maxOwnedIngredients(using: ref)
            return String(localized: "Maxed owned ingredients (skips perishable aberration fish).")
        },
        BulkAction(id: "maxAll", title: String(localized: "Max All Ingredients"), systemImage: "tray.2.fill",
                   description: String(localized: "Fill and inject every DLC-owned ingredient (skips aberration fish)."),
                   accent: Theme.Color.coral, buttonTitle: String(localized: "Max All"), section: .restaurant,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            doc.maxAllIngredients(using: ref)
            return String(localized: "Maxed all ingredients (skips perishable aberration fish).")
        },
        BulkAction(id: "maxBranch", title: String(localized: "Max Branch Store"), systemImage: "building.2.fill",
                   description: String(localized: "Stock the second store's separate branch counts — run alongside Max Owned."),
                   accent: Theme.Color.coral, buttonTitle: String(localized: "Max Branch"), section: .restaurant,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            doc.maxBranchIngredients(using: ref)
            return String(localized: "Maxed branch (2nd store) ingredients (skips aberration fish).")
        },
        BulkAction(id: "maxStaff", title: String(localized: "Max Staff Levels"), systemImage: "person.3.fill",
                   description: String(localized: "Level every hired restaurant staff member to the cap (20)."),
                   accent: Theme.Color.coral, buttonTitle: String(localized: "Max Staff"), section: .restaurant,
                   includeInMaxEverything: true) { doc, _ in
            String(localized: "Maxed \(doc.maxStaffLevels()) staff member(s) to level 20.")
        },
        // — Inventory —
        BulkAction(id: "maxInventory", title: String(localized: "Max Inventory Items"), systemImage: "shippingbox.fill",
                   description: String(localized: "Raise general materials / crafting parts."),
                   accent: Theme.Color.ocean, buttonTitle: String(localized: "Max Items"), section: .inventory,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            return String(localized: "Maxed inventory items (\(doc.maxInventoryItems(using: ref)) slots).")
        },
        BulkAction(id: "maxCraft", title: String(localized: "Max Craft Materials"), systemImage: "hammer.fill",
                   description: String(localized: "Stock fish parts + DREDGE research parts/bones so weapon crafting is unblocked."),
                   accent: Theme.Color.ocean, buttonTitle: String(localized: "Max Craft"), section: .inventory,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            return String(localized: "Maxed craft materials (\(doc.maxCraftMaterials(using: ref)) slots).")
        },
        BulkAction(id: "maxMerman", title: String(localized: "Max Merman Village"), systemImage: "drop.fill",
                   description: String(localized: "Fill the Sea People village inventory."),
                   accent: Theme.Color.ocean, buttonTitle: String(localized: "Max Village"), section: .inventory,
                   includeInMaxEverything: true) { doc, _ in
            String(localized: "Maxed merman village inventory (\(doc.maxMermanInventory()) slots).")
        },
        BulkAction(id: "maxSeeds", title: String(localized: "Max Farm Seeds"), systemImage: "leaf.fill",
                   description: String(localized: "Fill every owned seed / produce stack in the home farm."),
                   accent: Theme.Color.leaf, buttonTitle: String(localized: "Max Seeds"), section: .inventory,
                   includeInMaxEverything: true) { doc, _ in
            String(localized: "Maxed farm seeds / produce (\(doc.maxFarmStorage()) stacks).")
        },
        BulkAction(id: "maxFish", title: String(localized: "Max Caught-Fish Grade"), systemImage: "fish.fill",
                   description: String(localized: "Record the top size (grade 5) for every fish already caught. Doesn't add uncaught fish."),
                   accent: Theme.Color.ocean, buttonTitle: String(localized: "Max Fish"), section: .inventory,
                   includeInMaxEverything: true) { doc, _ in
            String(localized: "Set \(doc.maxCaughtFishGrades()) caught fish to top grade.")
        },
    ]
}
