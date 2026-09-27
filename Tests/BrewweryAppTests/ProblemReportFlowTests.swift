import AppKit
import BrewweryCore
import SwiftUI
import XCTest
@testable import Brewwery

/// Where "Report a problem" gets its content from: the environment for a plain report, and
/// the failed operation — live or from History — for "Report this failure".
@MainActor
final class ProblemReportFlowTests: XCTestCase {
    private var harness: AppTestHarness!
    private var app: AppEnvironment { harness.environment }

    override func setUp() async throws {
        harness = try AppTestHarness()
        await app.prepare()
        await harness.assertUsingDouble()
    }

    override func tearDown() async throws {
        harness?.tearDown()
    }

    func testAPlainReportCarriesTheEnvironmentAndNoFailure() throws {
        app.reportProblem()

        let draft = try XCTUnwrap(app.state.problemReport)
        XCTAssertEqual(draft.heading, "Report a problem")
        XCTAssertNil(draft.report.failure)

        let labels = draft.report.diagnostics.map(\.label)
        XCTAssertEqual(labels.prefix(3), ["Brewwery", "macOS", "Mac"])
        XCTAssertEqual(draft.report.diagnostics.first { $0.label == "Homebrew" }?.value, "4.5.0-test")
    }

    func testAFailedOperationBecomesAReportWithItsCommandAndOutput() async throws {
        await app.performServiceAction(.start, on: "broken")
        let progress = try XCTUnwrap(app.operations.progress)
        XCTAssertEqual(progress.status, .failed)

        app.reportFailure(of: progress)

        let failure = try XCTUnwrap(app.state.problemReport?.report.failure)
        XCTAssertEqual(failure.command, "brew services start broken")
        XCTAssertEqual(failure.result, "failed")
        XCTAssertEqual(failure.errorCode, BrewweryErrorCode.serviceCommandFailed.rawValue)
        XCTAssertFalse(failure.output.isEmpty, "the output is the most useful part of the report")
    }

    func testAFailedHistoryEntryCanBeReportedAfterThePanelIsGone() async throws {
        await app.performServiceAction(.start, on: "broken")
        app.operations.clear()
        let entry = try XCTUnwrap(app.history.entries.first { $0.status == .failed })

        app.reportFailure(of: entry)

        let failure = try XCTUnwrap(app.state.problemReport?.report.failure)
        XCTAssertEqual(failure.command, entry.command)
        XCTAssertEqual(app.state.problemReport?.heading, "Report this failure")
    }

    func testTheReportWindowRenders() async throws {
        await app.performServiceAction(.start, on: "broken")
        app.reportFailure(of: try XCTUnwrap(app.operations.progress))
        let draft = try XCTUnwrap(app.state.problemReport)

        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            let window = try await harness.host(
                ReportProblemView(draft: draft, onClose: {}),
                appearance: appearance,
                settle: .milliseconds(300)
            )
            let theme = appearance == .darkAqua ? "dark" : "light"
            XCTAssertTrue(try harness.snapshot(window, named: "overlay-report-\(theme)").hasVisibleContent)
        }
    }
}
