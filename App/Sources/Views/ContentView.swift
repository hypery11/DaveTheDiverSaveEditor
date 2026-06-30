// App/Sources/Views/ContentView.swift
import SwiftUI

/// Root editor screen. NavigationSplitView: sidebar of categories + a scroll of
/// cards. Owns no save/file logic — only composes views and the write-flow chrome.
struct ContentView: View {
    @Bindable var model: SaveEditorModel
    @State private var selection: EditorCategory? = .economy
    @State private var showingPreview = false

    var body: some View {
        NavigationSplitView {
            EditorSidebar(selection: $selection, model: model,
                          onLoad: loadSaveFile,
                          onSave: { showingPreview = true })
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
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
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.Color.bg)
            .navigationTitle((selection ?? .economy).label)
        }
        .frame(minWidth: 760, minHeight: 560)
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
                Button("Reveal Backup in Finder") { model.revealInFinder(url) }
                Button("OK") {}
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
