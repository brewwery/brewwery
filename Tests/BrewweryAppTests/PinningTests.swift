import BrewweryCore
import BrewweryTestSupport
import XCTest
@testable import Brewwery

/// `brew pin` says "leave this alone". The app has to agree everywhere: the command is
/// validated like any other, the Packages page and the drawer know the state, and a pinned
/// formula stops counting towards the outdated total the Dock badge shows.
@MainActor
final class PinningTests: XCTestCase {
    private var harness: AppTestHarness!
    private var app: AppEnvironment { harness.environment }

    override func setUp() async throws {
        harness = try AppTestHarness()
        await harness.assertUsingDouble()
    }

    override func tearDown() async throws {
        await harness?.tearDown()
    }

    func testPinCommandsAreValidatedLikeEveryOtherCommand() throws {
        XCTAssertEqual(try HomebrewCommand.pin(formula: "node").arguments(), ["pin", "node"])
        XCTAssertEqual(try HomebrewCommand.unpin(formula: "postgresql@17").arguments(), ["unpin", "postgresql@17"])
        XCTAssertEqual(try HomebrewCommand.listPinned.arguments(), ["list", "--pinned"])
        XCTAssertThrowsError(try HomebrewCommand.pin(formula: "node; rm -rf ~").arguments())
        XCTAssertThrowsError(try HomebrewCommand.unpin(formula: "../../etc").arguments())
    }

    func testPinningRecordsHistoryAndUpdatesTheLibrary() async throws {
        await app.library.loadFormulae()
        XCTAssertFalse(app.library.isPinned(name: "wget"))

        await app.setPinned(true, formula: "wget")

        XCTAssertTrue(app.library.isPinned(name: "wget"))
        let entry = try XCTUnwrap(app.history.entries.first)
        XCTAssertEqual(entry.kind, .pin)
        XCTAssertEqual(entry.status, .success)
        XCTAssertEqual(entry.command, "brew pin wget")

        await app.setPinned(false, formula: "wget")
        XCTAssertFalse(app.library.isPinned(name: "wget"))
        XCTAssertEqual(app.history.entries.first?.title, "Unpinned wget")
    }

    func testPinnedFormulaeAreListedButNotCounted() async throws {
        try harness.fake.setOutdated(formulae: ["node", "gh"], casks: ["docker-desktop"], pinned: ["node"])
        await app.updates.refresh()

        XCTAssertEqual(app.updates.updates.count, 3, "the Updates page still lists it")
        XCTAssertEqual(app.updates.count, 2, "the badge, sidebar and status bar leave it out")
        XCTAssertEqual(app.updates.pinnedCount, 1)
        XCTAssertEqual(AppDelegate.badgeLabel(count: app.updates.count, enabled: true), "2")
    }

    func testEverythingPinnedMeansNoBadge() async throws {
        try harness.fake.setOutdated(formulae: ["node"], pinned: ["node"])
        await app.updates.refresh()

        XCTAssertEqual(app.updates.count, 0)
        XCTAssertNil(AppDelegate.badgeLabel(count: app.updates.count, enabled: true))
    }

    func testPinConfirmationShowsTheCommand() {
        XCTAssertEqual(ConfirmationRequest.pin("node", pinned: true).command, "brew pin node")
        XCTAssertEqual(ConfirmationRequest.pin("node", pinned: false).command, "brew unpin node")
    }
}
