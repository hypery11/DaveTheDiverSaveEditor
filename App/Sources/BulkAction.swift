// App/Sources/BulkAction.swift
import SwiftUI
import DaveSaveCore

/// One bulk "max/fill" operation, described as data. This is the single source the
/// UI rows, "Max Everything", and the model's named entry points all derive from —
/// so the op's definition can't drift across those three call sites.
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
            preconditionFailure("unknown BulkAction id: \(id)")
        }
        return a
    }

    static let catalog: [BulkAction] = [
        // — Restaurant —
        BulkAction(id: "maxOwn", title: "Max Owned Ingredients", systemImage: "tray.full.fill",
                   description: "Fill every ingredient you already own (skips perishable aberration fish).",
                   accent: Theme.Color.coral, buttonTitle: "Max Own", section: .restaurant,
                   includeInMaxEverything: false) { doc, ref in           // superseded by Max All in Max Everything
            guard let ref else { return nil }
            doc.maxOwnedIngredients(using: ref)
            return "Maxed owned ingredients (skips perishable aberration fish)."
        },
        BulkAction(id: "maxAll", title: "Max All Ingredients", systemImage: "tray.2.fill",
                   description: "Fill and inject every DLC-owned ingredient (skips aberration fish).",
                   accent: Theme.Color.coral, buttonTitle: "Max All", section: .restaurant,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            doc.maxAllIngredients(using: ref)
            return "Maxed all ingredients (skips perishable aberration fish)."
        },
        BulkAction(id: "maxBranch", title: "Max Branch Store", systemImage: "building.2.fill",
                   description: "Stock the second store's separate branch counts — run alongside Max Owned.",
                   accent: Theme.Color.coral, buttonTitle: "Max Branch", section: .restaurant,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            doc.maxBranchIngredients(using: ref)
            return "Maxed branch (2nd store) ingredients (skips aberration fish)."
        },
        BulkAction(id: "maxStaff", title: "Max Staff Levels", systemImage: "person.3.fill",
                   description: "Level every hired restaurant staff member to the cap (20).",
                   accent: Theme.Color.coral, buttonTitle: "Max Staff", section: .restaurant,
                   includeInMaxEverything: true) { doc, _ in
            "Maxed \(doc.maxStaffLevels()) staff member(s) to level 20."
        },
        // — Inventory —
        BulkAction(id: "maxInventory", title: "Max Inventory Items", systemImage: "shippingbox.fill",
                   description: "Raise general materials / crafting parts.",
                   accent: Theme.Color.ocean, buttonTitle: "Max Items", section: .inventory,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            return "Maxed inventory items (\(doc.maxInventoryItems(using: ref)) slots)."
        },
        BulkAction(id: "maxCraft", title: "Max Craft Materials", systemImage: "hammer.fill",
                   description: "Stock fish parts + DREDGE research parts/bones so weapon crafting is unblocked.",
                   accent: Theme.Color.ocean, buttonTitle: "Max Craft", section: .inventory,
                   includeInMaxEverything: true) { doc, ref in
            guard let ref else { return nil }
            return "Maxed craft materials (\(doc.maxCraftMaterials(using: ref)) slots)."
        },
        BulkAction(id: "maxMerman", title: "Max Merman Village", systemImage: "drop.fill",
                   description: "Fill the Sea People village inventory.",
                   accent: Theme.Color.ocean, buttonTitle: "Max Village", section: .inventory,
                   includeInMaxEverything: true) { doc, _ in
            "Maxed merman village inventory (\(doc.maxMermanInventory()) slots)."
        },
        BulkAction(id: "maxSeeds", title: "Max Farm Seeds", systemImage: "leaf.fill",
                   description: "Fill every owned seed / produce stack in the home farm.",
                   accent: Theme.Color.leaf, buttonTitle: "Max Seeds", section: .inventory,
                   includeInMaxEverything: true) { doc, _ in
            "Maxed farm seeds / produce (\(doc.maxFarmStorage()) stacks)."
        },
        BulkAction(id: "maxFish", title: "Max Caught-Fish Grade", systemImage: "fish.fill",
                   description: "Record the top size (grade 5) for every fish already caught. Doesn't add uncaught fish.",
                   accent: Theme.Color.ocean, buttonTitle: "Max Fish", section: .inventory,
                   includeInMaxEverything: true) { doc, _ in
            "Set \(doc.maxCaughtFishGrades()) caught fish to top grade."
        },
    ]
}
