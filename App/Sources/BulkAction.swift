// App/Sources/BulkAction.swift
import SwiftUI
import DaveSaveCore

/// One bulk "max/fill" operation, described as data. This is the single source the
/// UI rows, "Max Everything", and the model's named entry points all derive from —
/// so the op's definition can't drift across those three call sites.
///
/// All user-facing text here goes through `String(localized:)`, so every title,
/// description, button label and status line lands in the String Catalog.
///
/// Deliberately no per-action accent colour: it derives from `section`, so a row can
/// never disagree with the section header above it. It used to be a field, and "Max
/// Seeds" kept leaf-green from a Farm category that had been folded into Inventory.
struct BulkAction: Identifiable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let description: String
    let buttonTitle: String
    let section: EditorCategory          // which pane's section renders it
    let includeInRunAll: Bool
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
                   buttonTitle: String(localized: "Max Own"), section: .restaurant,
                   includeInRunAll: false) { doc, ref in           // superseded by Max All in Max Everything
            guard let ref else { return nil }
            doc.maxOwnedIngredients(using: ref)
            return String(localized: "Maxed owned ingredients (skips perishable aberration fish).")
        },
        BulkAction(id: "maxAll", title: String(localized: "Max All Ingredients"), systemImage: "tray.2.fill",
                   description: String(localized: "Fill and inject every DLC-owned ingredient (skips aberration fish). Adds ingredients you haven't discovered yet."),
                   buttonTitle: String(localized: "Max All"), section: .restaurant,
                   includeInRunAll: true) { doc, ref in
            guard let ref else { return nil }
            doc.maxAllIngredients(using: ref)
            return String(localized: "Maxed all ingredients (skips perishable aberration fish).")
        },
        BulkAction(id: "maxBranch", title: String(localized: "Max Branch Store"), systemImage: "building.2.fill",
                   description: String(localized: "Stock the branch's separate ingredient counts — run alongside Max Owned."),
                   buttonTitle: String(localized: "Max Branch"), section: .restaurant,
                   includeInRunAll: true) { doc, ref in
            guard let ref else { return nil }
            doc.maxBranchIngredients(using: ref)
            return String(localized: "Maxed branch ingredients (skips aberration fish).")
        },
        BulkAction(id: "maxStaff", title: String(localized: "Max Staff Levels"), systemImage: "person.3.fill",
                   description: String(localized: "Level every hired restaurant staff member to the cap (20)."),
                   buttonTitle: String(localized: "Max Staff"), section: .restaurant,
                   includeInRunAll: true) { doc, _ in
            String(localized: "Maxed \(doc.maxStaffLevels()) staff member(s) to level 20.")
        },
        // — Inventory —
        BulkAction(id: "maxInventory", title: String(localized: "Max Inventory Items"), systemImage: "shippingbox.fill",
                   description: String(localized: "Raise general materials / crafting parts."),
                   buttonTitle: String(localized: "Max Items"), section: .inventory,
                   includeInRunAll: true) { doc, ref in
            guard let ref else { return nil }
            return String(localized: "Maxed inventory items (\(doc.maxInventoryItems(using: ref)) slots).")
        },
        BulkAction(id: "maxCraft", title: String(localized: "Max Craft Materials"), systemImage: "hammer.fill",
                   description: String(localized: "Stock fish parts + DREDGE research parts/bones so weapon crafting is unblocked. Adds parts you haven't found yet."),
                   buttonTitle: String(localized: "Max Craft"), section: .inventory,
                   includeInRunAll: true) { doc, ref in
            guard let ref else { return nil }
            return String(localized: "Maxed craft materials (\(doc.maxCraftMaterials(using: ref)) slots).")
        },
        BulkAction(id: "maxMerman", title: String(localized: "Max Sea People Village"), systemImage: "drop.fill",
                   description: String(localized: "Fill the Sea People Village storage."),
                   buttonTitle: String(localized: "Max Village"), section: .inventory,
                   includeInRunAll: true) { doc, _ in
            String(localized: "Maxed Sea People Village storage (\(doc.maxMermanInventory()) slots).")
        },
        BulkAction(id: "maxSeeds", title: String(localized: "Max Farm Seeds"), systemImage: "leaf.fill",
                   description: String(localized: "Fill every owned seed / produce stack in the home farm."),
                   buttonTitle: String(localized: "Max Seeds"), section: .inventory,
                   includeInRunAll: true) { doc, _ in
            String(localized: "Maxed farm seeds / produce (\(doc.maxFarmStorage()) stacks).")
        },
        BulkAction(id: "maxFish", title: String(localized: "Max Caught-Fish Grade"), systemImage: "fish.fill",
                   description: String(localized: "Record the top size (grade 5) for every fish already caught. Doesn't add uncaught fish."),
                   buttonTitle: String(localized: "Max Fish"), section: .inventory,
                   includeInRunAll: true) { doc, _ in
            String(localized: "Set \(doc.maxCaughtFishGrades()) caught fish to top grade.")
        },
    ]
}
