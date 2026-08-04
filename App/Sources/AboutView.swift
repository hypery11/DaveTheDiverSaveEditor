import SwiftUI

struct AboutView: View {
    static let windowID = "about"

    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSApplication.shared.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 88, height: 88)
            }
            Text(AppInfo.name)
                .font(.title2.bold())
            Text("Version \(AppInfo.version) (build \(AppInfo.build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("A free, open-source, 100% local save editor for macOS.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Credits")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 2) {
                    Link("FNGarvin/DaveSaveEd (MIT)",
                         destination: URL(string: "https://github.com/FNGarvin/DaveSaveEd")!)
                    Text("Original Windows save editor — feature set, save-path knowledge, and ingredient reference data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("WhiteMinds")
                        .fontWeight(.medium)
                    Text("Save codec reverse-engineering (char-level UTF-16 XOR).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("An independent reimplementation in Swift — not a fork.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Plain links at caption weight, no heart icon and no tint. For a tool that writes
            // to someone's only save file, plainer reads as more trustworthy than a styled
            // donate button — and the non-monetary ask is named first because for a
            // four-language project it is the one that actually helps most.
            VStack(alignment: .leading, spacing: 4) {
                Text("Free, and staying that way — no ads, no paid version, nothing locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("The most useful help is a bug report or a translation fix.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Link("Source Code", destination: SupportLinks.source)
                    Link("Support the Project", destination: SupportLinks.support)
                }
                .font(.caption)
                // Disclosed here rather than in the status-bar ask: About is a surface the user
                // navigated to, it sits beside the app's other trust claims, and it answers the
                // reader who ran `strings` on the binary before anyone reaches a wallet page.
                Text("Donations go through a crypto wallet page — there's no card option.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text("Not affiliated with, endorsed by, or associated with MINTROCKET or NEXON. \u{201C}Dave the Diver\u{201D} and related marks belong to their respective owners.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(AppInfo.copyright)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
