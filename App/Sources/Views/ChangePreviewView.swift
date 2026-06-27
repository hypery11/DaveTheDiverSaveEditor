import SwiftUI
import DaveSaveCore

/// Confirm-before-write sheet. Presents the pending field diff and the safety
/// note, then dispatches to `model.write()`. All persistence logic lives in
/// the model; this view only displays and dispatches.
struct ChangePreviewView: View {
    let model: SaveEditorModel
    @Environment(\.dismiss) private var dismiss

    /// Steam-Cloud + early-scripting safety copy (spec §4.2 / §7, R6/R7).
    static let safetyNote = """
        Quit Dave the Diver before writing. If Steam Cloud is enabled it can \
        overwrite your edited save the next time the game syncs — turn off \
        Cloud Saves for the game while editing. Early-game scripting may \
        recompute Gold or Follower Count, so reload the save and verify your \
        changes stuck. A timestamped backup is written automatically first.
        """

    var body: some View {
        let changes = model.pendingChanges()

        VStack(alignment: .leading, spacing: 0) {
            Text("Review Changes")
                .font(.title2.weight(.semibold))
                .padding([.top, .horizontal], 20)
                .padding(.bottom, 12)

            if changes.isEmpty {
                Text("No changes to write.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .padding(.horizontal, 20)
            } else {
                List(changes, id: \.path) { change in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(change.path)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text(change.oldValue.isEmpty ? "—" : change.oldValue)
                            .font(.callout.monospaced())
                        Image(systemName: "arrow.right")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                        Text(change.newValue)
                            .font(.callout.monospaced().weight(.semibold))
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 160)
            }

            Label(Self.safetyNote, systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.titleAndIcon)
                .font(.callout)
                .foregroundStyle(.secondary)
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
                .disabled(changes.isEmpty)
            }
            .padding(20)
        }
        .frame(minWidth: 480, minHeight: 380)
    }
}
