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

    private enum FocusTarget: Hashable { case itemSearch }
    @FocusState private var focus: FocusTarget?


    private var filteredItems: [SaveEditorModel.InventoryRow] {
        let all = model.inventoryRows()
        let q = itemQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) || String($0.id).contains(q) }
    }


    var body: some View {
        mainBody
            // Snapshot seam: open a sheet directly instead of driving menus in a UI test.
            // A sheet is a child window overlapping the parent, so a window-scoped
            // screenshot composites it in — no parallel view code needed.
            .onAppear {
                switch Snapshot.sheet {
                case "raw":     showingRaw = true
                case "backups": showingBackups = true
                case "preview": showingPreview = true
                default:        break
                }
            }
    }

    private var mainBody: some View {
        NavigationStack {
            // `List`, not `ScrollView` + `LazyVStack`: alternating row backgrounds are a
            // no-op outside a list or table, and zebra striping is the platform's own answer
            // to a long dense table (Finder, Xcode build settings, every DB client). It also
            // supplies row separators, so the hand-rolled `Divider()` after all 60+ rows is
            // gone. Same information architecture — one scroll, section headers, no tabs.
            List {
                // Economy
                Section {
                    ForEach(Currency.allCases) { c in
                        EconomyRow(model: model, currency: c).plainRow()
                    }
                } header: {
                    SectionHeader(category: .economy).plainRow()
                }

                // Restaurant (bulk fills)
                Section {
                    bulkRows(.restaurant)
                } header: {
                    SectionHeader(category: .restaurant).plainRow()
                }

                // Inventory (bulk fills + per-item browse)
                Section {
                    bulkRows(.inventory)

                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.Color.textSecondary)
                        TextField("Search items by name…", text: $itemQuery).textFieldStyle(.plain)
                            .focused($focus, equals: .itemSearch)
                    }
                    .padding(.horizontal, Theme.Spacing.xl).padding(.vertical, Theme.Spacing.sm)
                    .plainRow()

                    let items = filteredItems
                    if items.isEmpty {
                        Text(itemQuery.isEmpty ? "No inventory items." : "No items match “\(itemQuery)”.")
                            .font(.callout).foregroundStyle(Theme.Color.textSecondary)
                            .padding(.horizontal, Theme.Spacing.xl).padding(.vertical, Theme.Spacing.sm)
                            .plainRow()
                    } else {
                        ForEach(items) { row in
                            InventoryItemRow(model: model, row: row).plainRow()
                        }
                    }
                } header: {
                    SectionHeader(category: .inventory).plainRow()
                }

                // Advanced (add item by name/ID)
                Section {
                    AdvancedDetail(model: model).plainRow()
                } header: {
                    SectionHeader(category: .advanced).plainRow()
                }
            }
            .listStyle(.plain)
            .alternatingRowBackgrounds()
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bg)
            .overlay { if !model.isLoaded { emptyState } }
            .safeAreaInset(edge: .bottom) { statusBar }
            .navigationTitle(model.isLoaded ? (model.currentFileURL?.lastPathComponent ?? AppInfo.name)
                                            : AppInfo.name)
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
                    .help("Open a save slot or choose a file")

                    Button("Run All Fills", systemImage: "wand.and.stars") { model.runAllFills() }
                        .disabled(!model.isLoaded)
                        .labelStyle(.titleAndIcon)      // the most sweeping action carries its name
                        .help("Run every bulk fill at once. Does not change any currency.")

                    Menu {
                        Button("Raw JSON…", systemImage: "curlybraces") { showingRaw = true }
                        Button("Restore from Backup…", systemImage: "clock.arrow.circlepath") { showingBackups = true }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                    .disabled(!model.isLoaded)
                    .help("Raw JSON viewer and backups")

                    Button("Save…", systemImage: "tray.and.arrow.down") { showingPreview = true }
                        .disabled(!model.isLoaded || !model.hasChanges)
                        .help("Review the changes, then write them to the save")

                    Button("Support", systemImage: "heart.fill") {
                        model.supportPrompt = .launch
                    }
                    .labelStyle(.titleAndIcon)
                    .tint(Theme.Color.coral)
                    .help("DiveSaveEd is free — please consider supporting it")
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(WindowConfigurator(isEdited: model.hasChanges,
                                       representedURL: model.currentFileURL))
        .sheet(isPresented: $showingPreview) { ChangePreviewView(model: model) }
        .sheet(isPresented: $showingRaw) { RawJSONView(model: model) }
        .sheet(isPresented: $showingBackups) { BackupRestoreView(model: model) }
        .sheet(item: $model.supportPrompt) { SupportPromptView(kind: $0) }
        .onChange(of: model.requestWrite) { _, newValue in
            if newValue { showingPreview = true; model.requestWrite = false }
        }
        .alert(
            model.alert?.title ?? "",
            isPresented: Binding(get: { model.alert != nil }, set: {
                if !$0 {
                    // Arm on dismissal, not on presentation, so the ask never competes with a
                    // message the user still has to read.
                    let dismissed = model.alert
                    model.alert = nil
                    if dismissed?.kind == .writeSucceeded { model.registerWriteForSupportPrompt() }
                }
            }),
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
        // Also shows for `hasChanges`: nothing in the window used to say there was
        // unsaved work, because a currency edit sets neither a status string nor the
        // undo-able-bulk flag the bar was gated on.
        if model.isLoaded && (!model.ingredientStatus.isEmpty || model.canUndo || model.hasChanges) {
            HStack(spacing: Theme.Spacing.md) {
                if model.hasChanges {
                    Circle().fill(Theme.Color.coral)
                        .frame(width: Theme.Spacing.dirtyDotSize, height: Theme.Spacing.dirtyDotSize)
                        .accessibilityHidden(true)
                    Text("Unsaved changes").font(.callout).foregroundStyle(Theme.Color.textPrimary)
                }
                Text(model.ingredientStatus).font(.callout).foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
                Spacer()
                if model.canUndo {
                    // Names what it reverts, so it reads the same as the Edit menu item
                    // it mirrors rather than being a second, vaguer control.
                    Button(model.undoLabel.map { String(localized: "Undo \($0)") } ?? String(localized: "Undo"),
                           systemImage: "arrow.uturn.backward") { model.undo() }
                        .controlSize(.small)   // ⌘Z lives on the Edit menu item, not here
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

    /// All bulk-action rows for one section, derived from the single BulkAction.catalog.
    @ViewBuilder
    private func bulkRows(_ section: EditorCategory) -> some View {
        ForEach(BulkAction.catalog.filter { $0.section == section }) { action in
            BulkActionRow(title: action.title, systemImage: action.systemImage,
                          description: action.description, accent: action.section.accent,
                          buttonTitle: action.buttonTitle, isEnabled: model.isLoaded) { model.run(action) }
                .plainRow()
        }
    }

    private func slotLabel(_ s: SaveCandidate) -> String {
        // Include the containing folder (Steam-id / root) so same-named slots are distinguishable.
        "\(s.fileURL.lastPathComponent)  ·  \(s.directoryURL.lastPathComponent)  ·  \(s.modified.formatted(.relative(presentation: .named)))"
    }
}

private extension View {
    /// Hand a row's full width and padding back to the row itself. `List` otherwise applies
    /// its own insets on top of the ones every row type already carries, which would double
    /// the leading gutter and break the shared icon axis.
    func plainRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}
