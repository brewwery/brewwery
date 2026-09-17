import BrewweryCore
import BrewweryTestSupport
import XCTest
@testable import Brewwery

/// The outdated count is shown in four places — the Dock badge, the sidebar, the status bar
/// and the menu bar — and 1.0.0 computed the badge from its own `brew outdated` call. It
/// could therefore claim four updates while the window showed none, and it kept the old
/// number for up to half an hour after an upgrade. These tests pin down the rule that
/// replaced it: one list in `UpdatesModel`, read by everything.
@MainActor
final class OutdatedCountTests: XCTestCase {
    private var harness: AppTestHarness!
    private var app: AppEnvironment { harness.environment }

    override func setUp() async throws {
        harness = try AppTestHarness()
        await harness.assertUsingDouble()
    }

    override func tearDown() async throws {
        harness?.tearDown()
    }

    func testLaunchLoadsTheOutdatedListSoTheDockAndTheWindowAgree() async throws {
        try harness.fake.setOutdated(formulae: ["node", "gh"], casks: ["docker-desktop"])

        await app.prepare()

        XCTAssertEqual(app.updates.count, 3)
        XCTAssertEqual(app.updates.formulaeCount, 2)
        XCTAssertEqual(app.updates.casksCount, 1)
        XCTAssertNotNil(app.updates.lastChecked, "the page must be able to say when the count was read")
        XCTAssertFalse(app.updates.isLoading)
    }

    func testASilentRefreshKeepsTheLastGoodListAndRaisesNoError() async throws {
        try harness.fake.setOutdated(formulae: ["node"])
        await app.updates.refresh()
        XCTAssertEqual(app.updates.count, 1)

        // The background check runs while the user is reading a page: a failure there must
        // not blank the list, flash a skeleton, or put an error panel on screen.
        harness.fake.clearOutdated()
        await app.updates.refresh(silently: true)

        XCTAssertEqual(app.updates.count, 1)
        XCTAssertNil(app.updates.error)
        XCTAssertFalse(app.updates.isLoading)
    }

    func testAnExplicitRefreshStillReportsFailure() async throws {
        harness.fake.clearOutdated()

        await app.updates.refresh()

        XCTAssertNotNil(app.updates.error, "a refresh the user asked for must say when it failed")
    }

    func testUpgradingClearsTheCountImmediately() async throws {
        try harness.fake.setOutdated(formulae: ["node"])
        await app.updates.refresh()
        XCTAssertEqual(app.updates.count, 1)

        // What a successful upgrade does: Homebrew has nothing outdated left, and the app
        // re-reads both lists. In 1.0.0 the Dock kept showing "1" until the next half-hour.
        try harness.fake.setOutdated()
        await app.invalidateAfterPackageChange()

        XCTAssertEqual(app.updates.count, 0)
        XCTAssertNil(AppDelegate.badgeLabel(count: app.updates.count, enabled: true))
    }

    func testBadgeLabelHidesZeroAndRespectsThePreference() {
        XCTAssertEqual(AppDelegate.badgeLabel(count: 4, enabled: true), "4")
        XCTAssertNil(AppDelegate.badgeLabel(count: 0, enabled: true), "no badge when nothing is outdated")
        XCTAssertNil(AppDelegate.badgeLabel(count: 4, enabled: false), "the preference switches the badge off")
    }

    func testMenuBarCarriesTheSameNumber() {
        XCTAssertEqual(AppDelegate.updatesMenuTitle(count: 0), "Check for updates")
        XCTAssertEqual(AppDelegate.updatesMenuTitle(count: 4), "Check for updates (4)")
    }

    func testTheDockPreferenceIsOnByDefaultAndPersists() throws {
        XCTAssertTrue(app.settings.showDockBadge)

        app.settings.showDockBadge = false
        let reloaded = SettingsStore(defaults: try XCTUnwrap(UserDefaults(suiteName: harness.suiteName)))

        XCTAssertFalse(reloaded.showDockBadge)
    }
}
