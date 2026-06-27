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
