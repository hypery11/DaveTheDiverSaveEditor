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
    /// There used to be an exception here: while Pages was off and `/support/` 404'd, the
    /// in-app prompt pointed straight at the wallet host. Pages is live, so every link is back
    /// on a project host and the loop covers all of them — which is what this test's name
    /// claimed even while one link sat outside it.
    @Test("every link in the binary is on a project host")
    func hostsAreAccountedFor() {
        let own = ["github.com", "hypery11.github.io"]
        for url in [SupportLinks.faq, SupportLinks.source, SupportLinks.issues, SupportLinks.support] {
            #expect(own.contains(url.host ?? ""), "\(url) is not a project host")
            #expect(url.scheme == "https")
        }
    }

    /// The app ships four languages but the site's support page is four separate URLs, so
    /// sending everyone to the English one silently undoes the reason for pointing at the
    /// project page at all: that it explains who `fsd` is *in the reader's own language*
    /// before they reach a wallet.
    @Test("the support page follows the app's language", arguments: [
        ("en", "support/"),
        ("zh-Hant", "zh-tw/support/"),
        ("zh-Hans", "zh/support/"),
        ("ko", "ko/support/"),
        ("de", "support/"),                                  // a language we don't ship
    ])
    func supportPageIsLocalized(localization: String, path: String) {
        #expect(SupportLinks.support(for: localization).absoluteString
                == "https://hypery11.github.io/DaveTheDiverSaveEditor/\(path)")
    }

    @Test("a bundle with no preferred localization still yields a usable URL")
    func supportPageWithoutLocalization() {
        #expect(SupportLinks.support(for: nil).absoluteString
                == "https://hypery11.github.io/DaveTheDiverSaveEditor/support/")
    }
}
