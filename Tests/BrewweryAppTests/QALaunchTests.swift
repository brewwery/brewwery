import BrewweryCore
import XCTest
@testable import Brewwery

@MainActor
final class QALaunchTests: XCTestCase {
    func testOnlyAnExplicitValidatedNameSelectsAQAProfile() throws {
        XCTAssertNil(try QALaunch.parse(["Brewwery"]))
        for arguments in [["Brewwery", "--qa-profile"], ["Brewwery", "--qa-profile", "../Brewwery"],
                          ["Brewwery", "--qa-profile", "/tmp/test"], ["Brewwery", "--qa-profile", ""],
                          ["Brewwery", "--qa-profile", "one", "--qa-profile", "two"]] {
            XCTAssertThrowsError(try QALaunch.parse(arguments))
        }
        let profile = try XCTUnwrap(QALaunch.parse(["Brewwery", "--qa-profile", "clean-111"]))
        XCTAssertEqual(profile.preferencesSuite, "com.brewwery.qa.clean-111")
        XCTAssertEqual(profile.directory.lastPathComponent, "clean-111")
        XCTAssertEqual(profile.directory.deletingLastPathComponent().lastPathComponent, "Brewwery QA")
    }

    func testCleanProfilePersistsFavoritesHistoryAndSettingsAcrossRelaunch() async throws {
        let profile = QALaunch(name: "test-\(UUID().uuidString)")
        addTeardownBlock { @MainActor in
            UserDefaults.standard.removePersistentDomain(forName: profile.preferencesSuite)
            try? FileManager.default.removeItem(at: profile.directory)
        }
        let first = profile.makeEnvironment()
        XCTAssertTrue(first.history.entries.isEmpty)
        XCTAssertTrue(first.favorites.favorites.isEmpty)
        XCTAssertEqual(first.settings.theme, .dark)
        XCTAssertFalse(first.settings.automaticallyCheckForUpdates)
        first.settings.theme = .light
        first.favorites.add(name: "redis", kind: .formula)
        first.history.add(HistoryEntry(kind: .doctor, status: .success, title: "QA restart"))
        let saved = await first.flushPersistence()
        XCTAssertTrue(saved)

        let second = profile.makeEnvironment()
        XCTAssertEqual(second.settings.theme, .light)
        XCTAssertTrue(second.favorites.isFavorite(name: "redis", kind: .formula))
        XCTAssertEqual(second.history.entries.first?.title, "QA restart")
        XCTAssertFalse(second.history.hasUnsavedChanges)
        XCTAssertFalse(second.favorites.hasUnsavedChanges)
    }
}
