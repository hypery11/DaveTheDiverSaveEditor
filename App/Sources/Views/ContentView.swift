// App/Sources/Views/ContentView.swift
import SwiftUI

/// Root editor screen. NavigationSplitView: sidebar of categories + a scroll of
/// cards. Owns no save/file logic — only composes views and the write-flow chrome.
struct ContentView: View {
    @Bindable var model: SaveEditorModel
    @State private var selection: EditorCategory? = ContentView.snapshotCategory ?? .economy
    @State private var showingPreview = false

    /// Snapshot/UI-test seams (no effect on normal launches):
    /// `--args -snapshot-category <raw>` preselects a category; `-snapshot-appearance dark|light`
    /// forces the color scheme — so an automated capture can grab any pane in either mode.
    private static var snapshotCategory: EditorCategory? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-snapshot-category"), i + 1 < a.count else { return nil }
        return EditorCategory(rawValue: a[i + 1])
    }
    private static var snapshotColorScheme: ColorScheme? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-snapshot-appearance"), i + 1 < a.count else { return nil }
        switch a[i + 1] {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil
        }
    }

    var body: some View {
        NavigationSplitView {
            EditorSidebar(selection: $selection, model: model,
                          onLoad: loadSaveFile,
                          onSave: { showingPreview = true })
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            ZStack {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        switch selection ?? .economy {
                        case .economy:    EconomyDetail(model: model)
                        case .restaurant: RestaurantDetail(model: model)
                        case .farm:       FarmDetail(model: model)
                        case .inventory:  InventoryDetail(model: model)
                        case .advanced:   AdvancedDetail(model: model)
                        }
                    }
                    .frame(maxWidth: Theme.contentMaxWidth, alignment: .leading)
                    .padding(Theme.Spacing.xl)
                    .frame(maxWidth: .infinity)   // center the card column in wide windows
                }
                .background(Theme.Color.bg)

                if !model.isLoaded {
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.Color.ocean)
                        Text("No save loaded")
                            .font(Theme.cardTitleFont)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("Use Load to open a Dave the Diver save file.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Color.textSecondary)
                        Button("Load Save…", action: loadSaveFile)
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.Color.ocean)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Color.bg)
                }
            }
            .navigationTitle((selection ?? .economy).label)
        }
        .frame(minWidth: 760, minHeight: 560)
        .preferredColorScheme(Self.snapshotColorScheme)
        .sheet(isPresented: $showingPreview) { ChangePreviewView(model: model) }
        // Menu ⌘S sets model.requestWrite; observe here to present the sheet.
        .onChange(of: model.requestWrite) { _, newValue in
            if newValue { showingPreview = true; model.requestWrite = false }
        }
        .alert(
            model.alert?.title ?? "",
            isPresented: Binding(
                get: { model.alert != nil },
                set: { if !$0 { model.alert = nil } }
            ),
            presenting: model.alert
        ) { appAlert in
            if let url = appAlert.revealURL {
                Button("OK") {}
                Button("Reveal Backup in Finder") { model.revealInFinder(url) }
            } else {
                Button("OK") {}
            }
        } message: { appAlert in
            Text(appAlert.message)
        }
    }

    private func loadSaveFile() {
        if let url = FileDialogs.openSaveFile(startDirectory: model.detected?.directoryURL) {
            model.load(url: url)
        }
    }
}
