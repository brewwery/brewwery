import BrewweryCore
import BrewweryTestSupport
import XCTest
@testable import Brewwery

/// The flows behind the buttons: operations recording history and toasts, the search
/// debounce, installed-state lookups and the Updates/metadata distinction.
@MainActor
final class FeatureTests: XCTestCase {
    private var harness: AppTestHarness!
    private var app: AppEnvironment { harness.environment }

    override func setUp() async throws {
        harness = try AppTestHarness()
        await harness.assertUsingDouble()
    }

    override func tearDown() async throws {
        harness?.tearDown()
    }

    // MARK: - Operations

    func testSuccessfulInstallRecordsHistoryAndRaisesASuccessToast() async {
        await app.installPackage(.init(name: "hello", kind: .formula))

        let entry = try? XCTUnwrap(app.history.entries.first)
        XCTAssertEqual(entry?.kind, .install)
        XCTAssertEqual(entry?.status, .success)
        XCTAssertEqual(entry?.title, "Installed hello")
        XCTAssertEqual(entry?.command, "brew install hello")
        XCTAssertTrue(entry?.stdout?.contains("==> Pouring hello") == true)
        XCTAssertTrue(entry?.stderr?.contains("Warning") == true)

        XCTAssertEqual(app.state.toasts.first?.tone, .success)
        XCTAssertEqual(app.state.toasts.first?.title, "Installed hello")
        XCTAssertEqual(app.operations.progress?.status, .success)
    }

    func testFailedServiceActionRecordsTheFailureWithItsCode() async {
        await app.performServiceAction(.start, on: "broken")

        let entry = app.history.entries.first
        XCTAssertEqual(entry?.status, .failed)
        XCTAssertEqual(entry?.title, "Failed to start broken")
        XCTAssertEqual(entry?.error?.code, .serviceCommandFailed)
        XCTAssertTrue(entry?.stderr?.contains("launchctl bootstrap") == true)
        XCTAssertEqual(app.state.toasts.first?.tone, .error)
        XCTAssertEqual(app.operations.progress?.status, .failed)
    }

    func testCancelledUpgradeIsRecordedAsCancelled() async throws {
        let run = Task { await app.upgradePackage(.init(name: "redis", kind: .formula)) }
        _ = await harness.fake.waitForGrandchildPID()

        await app.operations.cancel()
        await run.value

        let entry = app.history.entries.first
        XCTAssertEqual(entry?.status, .cancelled)
        XCTAssertEqual(entry?.title, "Cancelled upgrade of redis")
        XCTAssertEqual(app.state.toasts.first?.tone, .info)
    }

    func testASecondOperationIsRefusedAndLogged() async throws {
        let first = Task { await app.upgradePackage(.init(name: "redis", kind: .formula)) }
        _ = await harness.fake.waitForGrandchildPID()

        await app.installPackage(.init(name: "hello", kind: .formula))

        XCTAssertEqual(app.history.entries.first?.error?.code, .operationInProgress)
        await app.operations.cancel()
        await first.value
    }

    /// `brew update` and `brew upgrade` are different operations and must be logged as such.
    func testMetadataRefreshIsLoggedSeparatelyFromUpgrades() async {
        await app.refreshHomebrewMetadata()

        XCTAssertEqual(app.history.entries.first?.kind, .brewUpdate)
        XCTAssertEqual(app.history.entries.first?.command, "brew update")
        XCTAssertEqual(app.history.entries.first?.title, "Updated Homebrew metadata")
    }

    func testTapActionsAreLogged() async {
        await app.performTapAction(.tap, name: "user/tools")

        XCTAssertEqual(app.history.entries.first?.title, "Added tap user/tools")
        XCTAssertEqual(app.history.entries.first?.command, "brew tap user/tools")
    }

    func testDoctorRunIsLoggedWithItsDiagnosticCount() async {
        await app.runDoctor()

        XCTAssertEqual(app.history.entries.first?.title, "Doctor completed with diagnostics")
        XCTAssertEqual(app.history.entries.first?.details, "1 diagnostics")
        XCTAssertEqual(app.doctor.result?.diagnostics.count, 1)
    }

    // MARK: - Search

    func testTypingQuicklyRunsOnlyTheLastQuery() async throws {
        let search = SearchModel(client: app.client)
        for prefix in ["h", "he", "hel", "hell", "hello"] {
            search.search(prefix)
            try await Task.sleep(for: .milliseconds(40))
        }

        try await Task.sleep(for: SearchModel.debounce + .milliseconds(900))

        XCTAssertEqual(search.activeQuery, "hello")
        XCTAssertEqual(search.results.map(\.name), ["hello", "hello-world", "hello-app"])
        XCTAssertEqual(search.results.last?.kind, .cask)
        XCTAssertFalse(search.isSearching)
    }

    func testNonLatinInputNeverReachesHomebrew() async throws {
        let search = SearchModel(client: app.client)
        search.search("редис")
        try await Task.sleep(for: SearchModel.debounce + .milliseconds(200))

        XCTAssertTrue(search.hasInvalidQuery)
        XCTAssertTrue(search.results.isEmpty)
        XCTAssertNil(search.error)
    }

    func testClearingTheQueryClearsResultsImmediately() async throws {
        let search = SearchModel(client: app.client)
        search.search("hello")
        try await Task.sleep(for: SearchModel.debounce + .milliseconds(900))
        XCTAssertFalse(search.results.isEmpty)

        search.search("   ")

        XCTAssertTrue(search.results.isEmpty)
        XCTAssertEqual(search.activeQuery, "")
    }

    // MARK: - Installed state and navigation

    func testInstalledLookupsAreCaseInsensitive() async {
        await app.library.loadAll()

        XCTAssertTrue(app.library.isInstalled(name: "WGET", kind: .formula))
        XCTAssertFalse(app.library.isInstalled(name: "wget", kind: .cask))
        XCTAssertEqual(app.library.installedVersion(for: "wget", kind: .formula), "1.25.0")
        XCTAssertEqual(app.library.leaves, ["redis", "postgresql@17"])
    }

    func testServicesAreOrderedRunningFirst() async {
        await app.services.refresh()

        XCTAssertEqual(app.services.runningFirst.map(\.name), ["redis", "etcd"])
        XCTAssertEqual(app.services.count(of: .stopped), 1)
    }

    func testCommandKOpensSearchAndRequestsFocus() {
        app.state.beginSearch()

        XCTAssertEqual(app.state.page, .search)
        XCTAssertTrue(app.state.pendingSearchFocus)
    }

    func testToastsAreCappedAtThree() {
        for index in 0..<5 {
            app.state.show(Toast(tone: .info, title: "toast \(index)", description: nil))
        }

        XCTAssertEqual(app.state.toasts.map(\.title), ["toast 4", "toast 3", "toast 2"])
    }
}
