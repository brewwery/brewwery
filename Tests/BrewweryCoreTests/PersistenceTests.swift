import XCTest
@testable import BrewweryCore

@MainActor
final class PersistenceTests: XCTestCase {

    /// Every store in these tests lives in a throwaway directory, never in the real
    /// `~/Library/Application Support/Brewwery`.
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("brewwery-persistence-\(UUID().uuidString)", isDirectory: true)

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStoreName() -> String { "test-\(UUID().uuidString).json" }

    private func removeStore(named name: String) {}

    // MARK: - History

    func testHistoryKeepsNewestFirstAndCapsAtOneHundred() async {
        let name = makeStoreName()
        defer { removeStore(named: name) }
        let history = HistoryStore(fileName: name, directory: directory)

        for index in 0..<105 {
            history.add(HistoryEntry(kind: .install, status: .success, title: "entry \(index)"))
        }

        XCTAssertEqual(history.entries.count, 100)
        XCTAssertEqual(history.entries.first?.title, "entry 104")
        XCTAssertEqual(history.entries.last?.title, "entry 5")
        let saved = await history.flushPersistence()
        XCTAssertTrue(saved)
    }

    func testHistorySurvivesAReload() async {
        let name = makeStoreName()
        defer { removeStore(named: name) }

        let history = HistoryStore(fileName: name, directory: directory)
        history.add(
            HistoryEntry(kind: .tap, status: .failed, title: "Failed to add tap user/tools", command: "brew tap user/tools")
        )

        _ = await history.flushPersistence()
        let reloaded = HistoryStore(fileName: name, directory: directory)

        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries[0].command, "brew tap user/tools")
        XCTAssertEqual(reloaded.entries[0].status, .failed)
    }

    func testHistoryTrimsOversizedOutputBeforeStoring() async {
        let name = makeStoreName()
        defer { removeStore(named: name) }
        let history = HistoryStore(fileName: name, directory: directory)

        let stored = history.add(
            HistoryEntry(
                kind: .install,
                status: .success,
                title: "Installed redis",
                stdout: String(repeating: "x", count: 60_000)
            )
        )

        XCTAssertLessThan(stored.stdout?.count ?? 0, 60_000)
        XCTAssertTrue(stored.stdout?.contains("to keep History fast.") == true)
        _ = await history.flushPersistence()
    }

    func testHistoryClearsAndExports() async throws {
        let name = makeStoreName()
        defer { removeStore(named: name) }
        let history = HistoryStore(fileName: name, directory: directory)
        history.add(HistoryEntry(kind: .doctor, status: .success, title: "Doctor completed: healthy"))

        let data = try history.exportData()
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("Doctor completed: healthy"))

        history.clear()
        XCTAssertTrue(history.entries.isEmpty)
        _ = await history.flushPersistence()
        XCTAssertTrue(HistoryStore(fileName: name, directory: directory).entries.isEmpty)
    }

    func testCombinedOutputJoinsEveryStoredField() {
        let entry = HistoryEntry(
            kind: .cleanup,
            status: .failed,
            title: "Cleanup failed",
            stdout: "out",
            stderr: "err",
            details: "3 removal operations",
            error: BrewweryError(code: .cleanupRunFailed, message: "Cleanup failed.", raw: "raw")
        )

        XCTAssertEqual(entry.combinedOutput, "3 removal operations\n\nout\n\nerr\n\nraw")
    }

    // MARK: - Favorites

    func testFavoritesAreKindScopedAndCaseInsensitive() async {
        let name = makeStoreName()
        let favorites = FavoritesStore(fileName: name, directory: directory)

        favorites.add(name: "  Redis  ", kind: .formula)
        favorites.add(name: "redis", kind: .formula)
        favorites.add(name: "redis", kind: .cask)

        XCTAssertEqual(favorites.favorites.count, 2)
        XCTAssertTrue(favorites.isFavorite(name: "REDIS", kind: .formula))
        XCTAssertTrue(favorites.isFavorite(name: "redis", kind: .cask))
        XCTAssertFalse(favorites.isFavorite(name: "postgresql", kind: .formula))
        _ = await favorites.flushPersistence()
    }

    func testFavoritesToggleAndPersist() async {
        let name = makeStoreName()

        let favorites = FavoritesStore(fileName: name, directory: directory)
        favorites.toggle(name: "iterm2", kind: .cask)
        _ = await favorites.flushPersistence()
        XCTAssertTrue(FavoritesStore(fileName: name, directory: directory).isFavorite(name: "iterm2", kind: .cask))

        favorites.toggle(name: "iterm2", kind: .cask)
        _ = await favorites.flushPersistence()
        XCTAssertTrue(FavoritesStore(fileName: name, directory: directory).favorites.isEmpty)
    }

    func testEmptyFavoriteNamesAreIgnored() {
        let name = makeStoreName()
        let favorites = FavoritesStore(fileName: name, directory: directory)

        favorites.add(name: "   ", kind: .formula)

        XCTAssertTrue(favorites.favorites.isEmpty)
    }

    // MARK: - Settings

    func testWriteFailureIsVisibleAndRetryPersistsPendingFavorites() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocked = directory.appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: blocked)
        let favorites = FavoritesStore(directory: blocked)
        favorites.add(name: "redis", kind: .formula)
        let saved = await favorites.flushPersistence()
        XCTAssertFalse(saved)
        XCTAssertNotNil(favorites.persistenceError)
        XCTAssertTrue(favorites.hasUnsavedChanges)
        try FileManager.default.removeItem(at: blocked)
        favorites.retryPersistence()
        let retried = await favorites.flushPersistence()
        XCTAssertTrue(retried)
        XCTAssertNil(favorites.persistenceError)
        XCTAssertFalse(favorites.hasUnsavedChanges)
        XCTAssertTrue(FavoritesStore(directory: blocked).isFavorite(name: "redis", kind: .formula))
    }

    func testCorruptHistoryIsReportedAndBackedUpBeforeSaving() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = Data("corrupt history".utf8)
        try original.write(to: directory.appendingPathComponent("history.json"))
        let history = HistoryStore(directory: directory)
        XCTAssertNotNil(history.persistenceError)
        history.add(HistoryEntry(kind: .doctor, status: .success, title: "Doctor completed"))
        _ = await history.flushPersistence()
        XCTAssertNil(history.persistenceError)
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first { $0.pathExtension == "bak" })
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertEqual(HistoryStore(directory: directory).entries.count, 1)
    }

    func testSettingsDefaultsMatchTheLegacyApp() throws {
        let suiteName = "brewwery-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)

        // 0.9.7 shipped with dark as the default rather than following the system.
        XCTAssertEqual(settings.theme, .dark)
        XCTAssertFalse(settings.showPrereleaseUpdates)
        XCTAssertEqual(settings.customHomebrewPath, "")
    }

    func testSettingsPersistAcrossInstances() throws {
        let suiteName = "brewwery-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.theme = .light
        settings.customHomebrewPath = "/opt/homebrew/bin/brew"

        let reloaded = SettingsStore(defaults: defaults)

        XCTAssertEqual(reloaded.theme, .light)
        XCTAssertEqual(reloaded.customHomebrewPath, "/opt/homebrew/bin/brew")
    }
}
