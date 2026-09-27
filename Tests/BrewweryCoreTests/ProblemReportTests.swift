import XCTest
@testable import BrewweryCore

/// A report leaves the Mac only when the user sends it, so what matters is that what they
/// see is what gets sent: account names masked, output bounded, links that actually open.
final class ProblemReportTests: XCTestCase {
    private let diagnostics = [
        ProblemReport.DiagnosticItem("Brewwery", "1.1.0"),
        ProblemReport.DiagnosticItem("Homebrew path", "/opt/homebrew/bin/brew")
    ]

    // MARK: - Redaction

    func testRedactsHomeDirectoriesButNotSharedOrSystemPaths() {
        XCTAssertEqual(ProblemReport.redact("/Users/alex/Library/Logs/x.log"), "~/Library/Logs/x.log")
        XCTAssertEqual(ProblemReport.redact("Error in /Users/alex"), "Error in ~")
        XCTAssertEqual(ProblemReport.redact("/Users/Shared/Brewfile"), "/Users/Shared/Brewfile")
        XCTAssertEqual(ProblemReport.redact("/opt/homebrew/Cellar/node"), "/opt/homebrew/Cellar/node")
        XCTAssertEqual(ProblemReport.redact(NSHomeDirectory() + "/Brewfile"), "~/Brewfile")
    }

    func testEverySectionOfTheReportIsRedacted() {
        let report = ProblemReport(
            description: "It broke in /Users/alex/dev",
            diagnostics: [.init("Brewfile", "/Users/alex/Brewfile")],
            failure: .init(
                command: "brew bundle dump --force --file=/Users/alex/Brewfile",
                result: "failed",
                errorCode: "BREWFILE_EXPORT_FAILED",
                errorMessage: "Could not write /Users/alex/Brewfile",
                output: "Error: Permission denied @ /Users/alex/Brewfile"
            )
        )

        let text = report.markdown()
        XCTAssertFalse(text.contains("/Users/alex"), text)
        XCTAssertTrue(report.title.contains("~/Brewfile"))
    }

    // MARK: - Content

    func testMarkdownShowsTheFailureOutputAndEnvironment() {
        let report = ProblemReport(
            description: "Install of wget never finished.",
            diagnostics: diagnostics,
            failure: .init(
                command: "brew install wget",
                result: "timed out",
                errorCode: "OPERATION_TIMEOUT",
                errorMessage: "The Homebrew operation exceeded its safety timeout.",
                output: "==> Fetching wget\n==> Downloading https://ghcr.io/wget"
            )
        )

        let text = report.markdown()
        XCTAssertTrue(text.contains("### What happened\n\nInstall of wget never finished."))
        XCTAssertTrue(text.contains("- Command: `brew install wget`"))
        XCTAssertTrue(text.contains("- Result: timed out (`OPERATION_TIMEOUT`)"))
        XCTAssertTrue(text.contains("==> Downloading https://ghcr.io/wget"))
        XCTAssertTrue(text.contains("| Brewwery | 1.1.0 |"))
        XCTAssertEqual(report.title, "Timed Out: brew install wget")
    }

    func testTogglesLeaveTheirSectionsOut() {
        var report = ProblemReport(
            description: "x",
            diagnostics: diagnostics,
            failure: .init(command: "brew doctor", result: "failed", errorCode: nil, errorMessage: nil, output: "secret-ish output")
        )
        report.includeDiagnostics = false
        report.includeOutput = false

        let text = report.markdown()
        XCTAssertFalse(text.contains("### Environment"))
        XCTAssertFalse(text.contains("secret-ish output"))
        XCTAssertTrue(text.contains("- Command: `brew doctor`"), "the command itself always stays")
    }

    func testOutputKeepsOnlyTheLastLines() {
        let output = (1...200).map { "line \($0)" }.joined(separator: "\n")
        let report = ProblemReport(
            diagnostics: [],
            failure: .init(command: "brew upgrade", result: "failed", errorCode: nil, errorMessage: nil, output: output)
        )

        let text = report.markdown()
        XCTAssertTrue(text.contains("line 200"))
        XCTAssertTrue(text.contains("line \(200 - ProblemReport.outputLineLimit + 1)\n"))
        XCTAssertFalse(text.contains("line \(200 - ProblemReport.outputLineLimit)\n"))
    }

    func testEmptyDescriptionIsSaidOutLoudAndTitledGenerically() {
        let report = ProblemReport(diagnostics: diagnostics)
        XCTAssertTrue(report.markdown().contains("_No description given._"))
        XCTAssertEqual(report.title, "Problem report")
    }

    func testOutputContainingBackticksUsesADifferentFence() {
        let report = ProblemReport(
            diagnostics: [],
            failure: .init(command: "brew doctor", result: "failed", errorCode: nil, errorMessage: nil, output: "Run ```brew cleanup```")
        )
        XCTAssertTrue(report.markdown().contains("~~~\nRun ```brew cleanup```\n~~~"))
    }

    // MARK: - Links

    func testIssueLinkPointsAtTheRepositoryAndPassesTheAllowlist() throws {
        let report = ProblemReport(description: "Search shows nothing", diagnostics: diagnostics)
        let (url, truncated) = report.githubIssueURL()

        XCTAssertFalse(truncated)
        XCTAssertTrue(ExternalLinkPolicy.isAllowed(url.absoluteString), url.absoluteString)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "title" }?.value, "Search shows nothing")
        XCTAssertEqual(items.first { $0.name == "body" }?.value, report.markdown())
    }

    func testLongOutputIsTrimmedUntilTheLinkFits() {
        // Sixty lines of this are far past what a pre-filled GitHub link can carry.
        let path = String(repeating: "/very/deep/build/directory", count: 6)
        let noisy = (1...400).map { "==> Pouring package-\($0) from \(path)/package-\($0)--1.0.arm64_sequoia.bottle.tar.gz" }
            .joined(separator: "\n")
        let report = ProblemReport(
            diagnostics: diagnostics,
            failure: .init(command: "brew upgrade", result: "failed", errorCode: nil, errorMessage: nil, output: noisy)
        )

        let (url, truncated) = report.githubIssueURL()
        XCTAssertTrue(truncated, "the caller must know to copy the full report")
        XCTAssertLessThanOrEqual(url.absoluteString.count, ProblemReport.issueURLLimit)
        XCTAssertTrue(url.absoluteString.contains("400"), "the last lines are the ones kept")
    }

    func testAnEnormousDescriptionStillProducesAWorkingLink() {
        let report = ProblemReport(description: String(repeating: "a very long description ", count: 2_000), diagnostics: diagnostics)
        let (url, truncated) = report.githubIssueURL()

        XCTAssertTrue(truncated)
        XCTAssertLessThanOrEqual(url.absoluteString.count, ProblemReport.issueURLLimit)
    }

    func testMailLinkGoesOnlyToTheSupportAddress() throws {
        let report = ProblemReport(description: "Hello", diagnostics: diagnostics)
        let (url, _) = report.mailURL()

        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertTrue(ExternalLinkPolicy.isAllowedMail(url))
        XCTAssertFalse(ExternalLinkPolicy.isAllowedMail(try XCTUnwrap(URL(string: "mailto:someone@example.com"))))
        XCTAssertFalse(ExternalLinkPolicy.isAllowedMail(try XCTUnwrap(URL(string: "https://brewwery.com"))))
    }

    // MARK: - System facts

    func testSystemFactsDescribeThisMac() {
        XCTAssertTrue(SystemFacts.macOSVersion.hasPrefix("\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)."))
        XCTAssertNotEqual(SystemFacts.hardwareModel, "")
        XCTAssertNotEqual(SystemFacts.processArchitecture, "unknown")
    }
}
