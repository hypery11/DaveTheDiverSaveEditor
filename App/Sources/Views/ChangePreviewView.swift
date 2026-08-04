import SwiftUI
import DaveSaveCore

/// Confirm-before-write sheet. Presents the pending field diff and the safety
/// note, then dispatches to `model.write()`. All persistence logic lives in
/// the model; this view only displays and dispatches.
struct ChangePreviewView: View {
    let model: SaveEditorModel
    @Environment(\.dismiss) private var dismiss

    /// Dotted JSON path → the row label the user actually clicked. Built from the engine's
    /// own scalar table, so it can't drift from what the rows edit.
    private static let labelForPath: [String: String] = Dictionary(
        uniqueKeysWithValues: Currency.allCases.compactMap { currency in
            SaveDocument.dottedPath(forID: currency.rawValue).map { ($0, currency.label) }
        })

    /// The staged cloud copy's date, in the user's locale. Falls back to an em dash rather
    /// than an empty string so the sentence never reads as truncated.
    private var cloudCopyDate: String {
        model.steamCloud.cloudCopyModified?.formatted(date: .abbreviated, time: .shortened) ?? "—"
    }

    var body: some View {
        let changes = model.pendingChanges()
        let bulkOps = model.appliedBulkOps

        VStack(alignment: .leading, spacing: 0) {
            Text("Review Changes")
                .font(.title2.weight(.semibold))
                .padding([.top, .horizontal], 20)
                .padding(.bottom, 12)

            if !model.hasChanges {
                Text("No changes to write.")
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding(.horizontal, 20)
            } else {
                List {
                    if !changes.isEmpty {
                        Section("Values") {
                            ForEach(changes, id: \.path) { change in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    // Lead with the localized row name; keep the raw path
                                    // as a caption for anyone who wants it. This sheet is
                                    // otherwise fully localized, and it used to identify
                                    // the user's edits only as `PlayerInfo.m_ChefFlame`.
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(Self.labelForPath[change.path] ?? change.path)
                                            .font(.callout)
                                            .foregroundStyle(Theme.Color.textPrimary)
                                        Text(change.path)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(Theme.Color.textSecondary)
                                    }
                                    Spacer(minLength: 12)
                                    Text(change.oldValue.isEmpty ? "—" : change.oldValue)
                                        .font(.callout.monospaced())
                                    Image(systemName: "arrow.right")
                                        .imageScale(.small)
                                        .foregroundStyle(Theme.Color.textSecondary)
                                    Text(change.newValue)
                                        .font(.callout.monospaced().weight(.semibold))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    if !bulkOps.isEmpty {
                        Section("Bulk edits") {
                            ForEach(Array(bulkOps.enumerated()), id: \.offset) { _, op in
                                Label(op, systemImage: "wand.and.stars")
                                    .font(.callout)
                            }
                        }
                    }
                }
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
            }

            // Localized, and two short lines instead of a five-sentence paragraph. It was
            // a plain `String` passed to `Label(_:systemImage:)` — the non-localizing
            // initializer — so the one hazard the app cannot defend against itself was
            // English-only in three of four locales, at the exact moment before an
            // overwrite. "Quit the game first" is gone because SaveGuard hard-blocks that.
            // `info.circle`, not a caution triangle: the HIG reserves that for unexpected
            // data loss, and a backup is written first.
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    // When we can actually prove Steam is staging this file, say so
                    // specifically. A detected, dated warning is worth far more than the
                    // generic advice every tool in this space gives after the fact — this
                    // is the #1 reason players think a save editor silently did nothing.
                    if model.steamCloud.cloudCopyExists {
                        Text("Steam Cloud has a copy of this save (\(cloudCopyDate)). Turn Cloud off for Dave the Diver in Steam, or it can replace your edit before the game loads.")
                            .foregroundStyle(Theme.Color.errorText)
                    } else {
                        Text("Turn off Steam Cloud for Dave the Diver before playing, or it can overwrite this save on its next sync.")
                    }
                    Text("Early in the game some values are recomputed by story scripts — reload and check they stuck.")
                }
            } icon: {
                Image(systemName: model.steamCloud.cloudCopyExists
                      ? "exclamationmark.triangle.fill" : "info.circle")
            }
            .font(.callout)
            .foregroundStyle(Theme.Color.warningText)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Write Save") {
                    model.write()        // @discardableResult; sets model.alert
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.hasChanges)
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 380)
        .background(Theme.Color.bg)
    }
}
