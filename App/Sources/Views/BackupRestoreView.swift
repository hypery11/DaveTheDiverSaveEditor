// App/Sources/Views/BackupRestoreView.swift
import SwiftUI

/// Lists the timestamped backups for the current save and restores a chosen one.
/// Restore overwrites the live save, but the model backs up the current state first
/// (and refuses while the game is running), so it's reversible + safe.
struct BackupRestoreView: View {
    let model: SaveEditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var backups: [Entry] = []
    @State private var confirmRestore: URL? = nil

    struct Entry: Identifiable {
        let id: URL
        let url: URL
        let modified: Date?
        var name: String { url.lastPathComponent }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if backups.isEmpty {
                    ContentUnavailableView(
                        "No backups yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("A timestamped backup is saved automatically each time you write this save.")
                    )
                } else {
                    List(backups) { b in
                        HStack(spacing: Theme.Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.modified.map { Self.dateFormatter.string(from: $0) } ?? b.name)
                                    .foregroundStyle(Theme.Color.textPrimary)
                                Text(b.name).font(.caption.monospaced()).foregroundStyle(Theme.Color.textSecondary)
                            }
                            Spacer()
                            Button("Restore") { confirmRestore = b.url }
                                .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Restore from Backup")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .frame(minWidth: 520, minHeight: 420)
        .background(Theme.Color.bg)
        .onAppear(perform: reload)
        .confirmationDialog(
            "Restore this backup?",
            isPresented: Binding(get: { confirmRestore != nil }, set: { if !$0 { confirmRestore = nil } }),
            presenting: confirmRestore
        ) { url in
            Button("Restore & Overwrite", role: .destructive) {
                model.restore(from: url); confirmRestore = nil; dismiss()
            }
            Button("Cancel", role: .cancel) { confirmRestore = nil }
        } message: { _ in
            Text("This overwrites the current save with the backup. Your current state is backed up first, so it's reversible.")
        }
    }

    private func reload() {
        backups = model.availableBackups().map { url in
            let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return Entry(id: url, url: url, modified: mod)
        }
    }
}
