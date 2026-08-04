// App/Sources/SupportLinks.swift
import Foundation

/// Every outbound URL the app can hand to the user's browser, in one place.
///
/// These are the only URLs in the binary, which keeps a claim easy to check: grep the app and
/// you find `hypery11.github.io` and `github.com`, nothing else. Opening one hands the URL to
/// the browser via `NSWorkspace` — **the app itself still makes no network request**, which is
/// what the zero-network guarantee actually promises. Nothing here is fetched, prefetched, or
/// contacted at launch.
enum SupportLinks {
    private static let site = "https://hypery11.github.io/DaveTheDiverSaveEditor"
    private static let repo = "https://github.com/hypery11/DaveTheDiverSaveEditor"

    static let faq    = URL(string: "\(site)/faq/")!
    static let source = URL(string: repo)!
    static let issues = URL(string: "\(repo)/issues/new/choose")!

    /// The project's own support page, which then links out to the donation page.
    ///
    /// The indirection is the load-bearing part, for two reasons. Wikimedia's banner tests are
    /// the one measured finding in this area: identical click-through, roughly twice the
    /// donations, entirely decided *after* the click. And the donation page itself is titled
    /// "Send to fsd" over a bare `0x…` and a QR code — it never names this app or its author,
    /// which is precisely the identity break every anti-phishing lesson trains people to back
    /// out of. The project page closes that gap first, in the reader's own language, and
    /// discloses crypto-only before anyone reaches a wallet.
    ///
    /// It also keeps every URL in the binary on a project host, so `strings` on the app — how a
    /// suspicious user actually checks the zero-network claim — comes out clean.
    static let support = URL(string: "\(site)/support/")!

    /// Where the in-app surfaces actually send people, for now.
    ///
    /// It should be `support` above — the project page closes the identity gap and keeps the
    /// binary free of third-party hosts. But GitHub Pages is not enabled on this repo yet
    /// (private repos need a paid plan), so `/support/` is currently a 404, and a donation
    /// prompt whose button leads nowhere is worse than the host concern. Flip this back to
    /// `support` the moment Pages is live.
    static let donate = URL(string: "https://fsd.fkey.id/")!
}

/// Builds a GitHub "new issue" URL with the diagnostics block already in the body.
///
/// The audience is largely not on GitHub and often not writing in English, so every step
/// removed from filing a report matters. Callers should still copy the block to the clipboard
/// first: if GitHub changes its prefill parameters or the payload is over-length, the report
/// degrades to "paste this" rather than being lost.
enum IssueReport {
    /// GitHub truncates very long query strings and browsers have their own ceilings, so keep
    /// the prefilled body well clear of both. The diagnostics block is a few hundred bytes;
    /// this only bites if it ever grows.
    private static let maxBodyLength = 6000

    static func url(diagnostics: String, template: String = "bug_report.yml") -> URL {
        var components = URLComponents(string:
            "https://github.com/hypery11/DaveTheDiverSaveEditor/issues/new")!
        let body = diagnostics.count > maxBodyLength
            ? String(diagnostics.prefix(maxBodyLength))
            : diagnostics
        components.queryItems = [
            URLQueryItem(name: "template", value: template),
            URLQueryItem(name: "diagnostics", value: body),
        ]
        // Falls back to the plain chooser rather than failing: a report filed without the
        // prefill is far better than a dead menu item.
        return components.url ?? SupportLinks.issues
    }
}
