// App/Sources/Views/ContentView.swift
import SwiftUI
import DaveSaveCore

/// Root editor screen. A single scrolling table (no tabs): sections with pinned
/// headers + divider rows. Everything — currencies, bulk actions, and the item
/// browser — lives in one view.
struct ContentView: View {
    @Bindable var model: SaveEditorModel
    @State private var showingPreview = false
    @State private var showingRaw = false
    @State private var showingBackups = false
    @State private var confirmLoad: (() -> Void)? = nil
    @State private var itemQuery = ""

    /// Snapshot/UI-test seam: `-snapshot-appearance dark|light` forces the color scheme.
    private static var snapshotColorScheme: ColorScheme? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-snapshot-appearance"), i + 1 < a.count else { return nil }
        switch a[i + 1] {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil
        }
    }

    /// Snapshot seam: `-snapshot-raw` auto-opens the Raw inspector on launch.
    private static var snapshotRaw: Bool { ProcessInfo.processInfo.arguments.contains("-snapshot-raw") }

    private var filteredItems: [SaveEditorModel.InventoryRow] {
        let all = model.inventoryRows()
        let q = itemQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) || String($0.id).contains(q) }
    }

    private func rowDivider() -> some View { Divider().padding(.leading, Theme.Spacing.xl) }

    var body: some View {
        if Self.snapshotRaw {
            RawJSONView(model: model)   // snapshot seam: capture the Raw view as the main window
                .preferredColorScheme(Self.snapshotColorScheme)
        } else {
            mainBody
        }
    }

    private var mainBody: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    // Economy
                    Section {
                        ForEach(Currency.allCases) { c in
                            EconomyRow(model: model, currency: c)
                            rowDivider()
                        }
                    } header: {
                        SectionHeader(title: "Economy", systemImage: "dollarsign.circle.fill", accent: Theme.Color.gold)
                    }

                    // Restaurant (bulk fills)
                    Section {
                        BulkActionRow(title: "Max Owned Ingredients", systemImage: "tray.full.fill",
                                      description: "Fill every ingredient you already own (skips perishable aberration fish).",
                                      accent: Theme.Color.coral, buttonTitle: "Max Own", isEnabled: model.isLoaded) { model.maxOwnIngredients() }
                        rowDivider()
                        BulkActionRow(title: "Max All Ingredients", systemImage: "tray.2.fill",
                                      description: "Fill and inject every DLC-owned ingredient (skips aberration fish).",
                                      accent: Theme.Color.coral, buttonTitle: "Max All", isEnabled: model.isLoaded) { model.maxAllIngredients() }
                        rowDivider()
                        BulkActionRow(title: "Max Branch Store", systemImage: "building.2.fill",
                                      description: "Stock the second store's separate branch counts — run alongside Max Owned.",
                                      accent: Theme.Color.coral, buttonTitle: "Max Branch", isEnabled: model.isLoaded) { model.maxBranchIngredients() }
                    } header: {
                        SectionHeader(title: "Restaurant", systemImage: "fork.knife", accent: Theme.Color.coral)
                    }

                    // Inventory (bulk fills + per-item browse)
                    Section {
                        BulkActionRow(title: "Max Inventory Items", systemImage: "shippingbox.fill",
                                      description: "Raise general materials / crafting parts.",
                                      accent: Theme.Color.ocean, buttonTitle: "Max Items", isEnabled: model.isLoaded) { model.maxInventoryItems() }
                        rowDivider()
                        BulkActionRow(title: "Max Craft Materials", systemImage: "hammer.fill",
                                      description: "Stock fish parts + DREDGE research parts/bones so weapon crafting is unblocked.",
                                      accent: Theme.Color.ocean, buttonTitle: "Max Craft", isEnabled: model.isLoaded) { model.maxCraftMaterials() }
                        rowDivider()
                        BulkActionRow(title: "Max Merman Village", systemImage: "drop.fill",
                                      description: "Fill the Sea People village inventory.",
                                      accent: Theme.Color.ocean, buttonTitle: "Max Village", isEnabled: model.isLoaded) { model.maxMermanInventory() }
                        rowDivider()
                        BulkActionRow(title: "Max Farm Seeds", systemImage: "leaf.fill",
                                      description: "Fill every owned seed / produce stack in the home farm.",
                                      accent: Theme.Color.leaf, buttonTitle: "Max Seeds", isEnabled: model.isLoaded) { model.maxSeeds() }
                        rowDivider()

                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.textSecondary)
                            TextField("Search items by name…", text: $itemQuery).textFieldStyle(.plain)
                        }
                        .padding(.horizontal, Theme.Spacing.xl).padding(.vertical, Theme.Spacing.sm)
                        rowDivider()

                        let items = filteredItems
                        if items.isEmpty {
                            Text(itemQuery.isEmpty ? "No inventory items." : "No items match “\(itemQuery)”.")
                                .font(.callout).foregroundStyle(Theme.Color.textSecondary)
                                .padding(.horizontal, Theme.Spacing.xl).padding(.vertical, Theme.Spacing.sm)
                        } else {
                            ForEach(items) { row in
                                InventoryItemRow(model: model, row: row)
                                rowDivider()
                            }
                        }
                    } header: {
                        SectionHeader(title: "Inventory", systemImage: "shippingbox.fill", accent: Theme.Color.ocean)
                    }

                    // Advanced (add item by name/ID)
                    Section {
                        AdvancedDetail(model: model)
                    } header: {
                        SectionHeader(title: "Advanced", systemImage: "wrench.and.screwdriver.fill", accent: Theme.Color.slate)
                    }
                }
                .frame(maxWidth: 920, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.Color.bg)
            .onAppear { if Self.snapshotRaw && model.isLoaded { showingRaw = true } }
            .onChange(of: model.isLoaded) { _, loaded in if Self.snapshotRaw && loaded { showingRaw = true } }
            .overlay { if !model.isLoaded { emptyState } }
            .safeAreaInset(edge: .bottom) { statusBar }
            .navigationTitle(model.isLoaded ? (model.currentFileURL?.lastPathComponent ?? "Save Editor")
                                            : "Dave the Diver Save Editor")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        let saves = model.availableSaves()
                        if saves.isEmpty {
                            Text("No save slots detected")
                        } else {
                            Section("Save slots") {
                                ForEach(saves, id: \.fileURL) { s in
                                    Button(slotLabel(s)) { guardedLoad { model.load(url: s.fileURL) } }
                                }
                            }
                        }
                        Divider()
                        Button("Open File…") { guardedLoad(loadSaveFile) }
                    } label: {
                        Label("Open", systemImage: "folder")
                    }

                    Button("Max Everything", systemImage: "wand.and.stars") { model.maxEverything() }
                        .disabled(!model.isLoaded)

                    Menu {
                        Button("Raw JSON…", systemImage: "curlybraces") { showingRaw = true }
                        Button("Restore from Backup…", systemImage: "clock.arrow.circlepath") { showingBackups = true }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .disabled(!model.isLoaded)

                    Button("Save", systemImage: "square.and.arrow.up") { showingPreview = true }
                        .disabled(!model.isLoaded || !model.hasChanges)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(Self.snapshotColorScheme)
        .sheet(isPresented: $showingPreview) { ChangePreviewView(model: model) }
        .sheet(isPresented: $showingRaw) { RawJSONView(model: model) }
        .sheet(isPresented: $showingBackups) { BackupRestoreView(model: model) }
        .onChange(of: model.requestWrite) { _, newValue in
            if newValue { showingPreview = true; model.requestWrite = false }
        }
        .alert(
            model.alert?.title ?? "",
            isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
            presenting: model.alert
        ) { appAlert in
            if let url = appAlert.revealURL {
                Button("OK", role: .cancel) {}
                Button("Reveal Backup in Finder") { model.revealInFinder(url) }
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { appAlert in
            Text(appAlert.message)
        }
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: Binding(get: { confirmLoad != nil }, set: { if !$0 { confirmLoad = nil } }),
            presenting: confirmLoad
        ) { action in
            Button("Discard & Open", role: .destructive) { action(); confirmLoad = nil }
            Button("Cancel", role: .cancel) { confirmLoad = nil }
        } message: { _ in
            Text("Your edits to this save haven't been written. Opening another save will discard them.")
        }
    }

    @ViewBuilder private var statusBar: some View {
        if model.isLoaded && (!model.ingredientStatus.isEmpty || model.canUndoBulk) {
            HStack(spacing: Theme.Spacing.md) {
                Text(model.ingredientStatus).font(.callout).foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
                Spacer()
                if model.canUndoBulk {
                    Button("Undo last edit", systemImage: "arrow.uturn.backward") { model.undoLastBulk() }
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl).padding(.vertical, Theme.Spacing.sm)
            .background(.regularMaterial)
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "doc.badge.plus").font(.system(size: 48)).foregroundStyle(Theme.Color.ocean)
            Text("No save loaded").font(Theme.cardTitleFont).foregroundStyle(Theme.Color.textPrimary)
            if let detected = model.detected {
                Text("Found your latest save.").font(.subheadline).foregroundStyle(Theme.Color.textSecondary)
                Button("Open \(detected.fileURL.lastPathComponent)") { guardedLoad(model.loadDetected) }
                    .buttonStyle(.borderedProminent).tint(Theme.Color.ocean)
                Button("Choose Another…") { guardedLoad(loadSaveFile) }.buttonStyle(.bordered)
            } else {
                Text("Open a Dave the Diver save file to begin.").font(.subheadline).foregroundStyle(Theme.Color.textSecondary)
                Button("Open Save…") { guardedLoad(loadSaveFile) }.buttonStyle(.borderedProminent).tint(Theme.Color.ocean)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.bg)
    }

    /// Run `perform` immediately, or ask to discard first when there are unsaved edits.
    private func guardedLoad(_ perform: @escaping () -> Void) {
        if model.hasChanges { confirmLoad = perform } else { perform() }
    }

    private func loadSaveFile() {
        if let url = FileDialogs.openSaveFile(startDirectory: model.detected?.directoryURL) {
            model.load(url: url)
        }
    }

    private func slotLabel(_ s: SaveCandidate) -> String {
        "\(s.fileURL.lastPathComponent)  ·  \(s.modified.formatted(.relative(presentation: .named)))"
    }
}
