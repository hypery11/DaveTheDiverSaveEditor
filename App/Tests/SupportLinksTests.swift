import Foundation
import Testing
@testable import DaveTheDiverSaveEditor

/// The prefilled report URL is a contract with two things that live outside Swift: the
/// template's FILENAME and its field `id`. Either one changing silently drops the prefill —
/// GitHub ignores unknown parameters rather than erroring — so pin both here. The matching
/// field is `id: diagnostics` in .github/ISSUE_TEMPLATE/bug_report.yml.
@Suite("Support links")
struct SupportLinksTests {

    @Test("report URL targets the bug template and carries the diagnostics field")
    func reportURLShape() throws {
        let url = IssueReport.url(diagnostics: "version 1.3b\nmacOS 15.0")
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(parts.queryItems)

        #expect(parts.host == "github.com")
        #expect(parts.path == "/hypery11/DaveTheDiverSaveEditor/issues/new")
        #expect(items.first { $0.name == "template" }?.value == "bug_report.yml")
        #expect(items.first { $0.name == "diagnostics" }?.value?.contains("macOS 15.0") == true)
    }

    /// A newline-and-space payload has to survive percent-encoding, or the browser truncates
    /// the body at the first space.
    @Test("multi-line diagnostics survive URL encoding")
    func encodingSurvivesNewlines() throws {
        let url = IssueReport.url(diagnostics: "a b\nc\td")
        #expect(url.absoluteString.contains(" ") == false)
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(parts.queryItems?.first { $0.name == "diagnostics" }?.value == "a b\nc\td")
    }

    @Test("an over-length payload is truncated rather than producing a dead URL")
    func overLengthTruncated() throws {
        let url = IssueReport.url(diagnostics: String(repeating: "x", count: 20_000))
        let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let value = try #require(parts.queryItems?.first { $0.name == "diagnostics" }?.value)
        #expect(value.count == 6000)
    }

    /// `strings` on the binary is how a suspicious user checks the zero-network claim, so every
    /// host in the app has to be accounted for.
    ///
    /// This test previously iterated only the project-hosted links while `donate` — the one
    /// third-party host — sat outside the loop. It passed, under a name claiming every link was
    /// on a project host, which was no longer true. A test that quietly stops covering the thing
    /// it is named after is worse than no test, so both halves are pinned explicitly now.
    @Test("project links are own-host, and the donation link is the one accounted-for exception")
    func hostsAreAccountedFor() {
        let own = ["github.com", "hypery11.github.io"]
        for url in [SupportLinks.faq, SupportLinks.source, SupportLinks.issues, SupportLinks.support] {
            #expect(own.contains(url.host ?? ""), "\(url) is not a project host")
            #expect(url.scheme == "https")
        }
        // Temporary: in-app surfaces point straight at the wallet only while GitHub Pages is
        // off and /support/ 404s. When Pages is live this becomes SupportLinks.support and the
        // exception disappears.
        #expect(SupportLinks.donate.host == "fsd.fkey.id")
        #expect(SupportLinks.donate.scheme == "https")
    }
}
