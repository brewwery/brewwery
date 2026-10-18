import XCTest
@testable import BrewweryCore

@MainActor
final class BackgroundPersistenceTests: XCTestCase {
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("brewwery-background-\(UUID().uuidString)")

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testCoalescesPendingSnapshotsAndFlushWaitsForTheLatest() async throws {
        let probe = WriteProbe()
        let persistence = JSONPersistence(store: JSONFileStore<Int>(fileName: "state.json", directory: directory), write: probe.save)
        persistence.save(1)
        try await waitForFirstWrite(probe)
        persistence.save(2)
        persistence.save(3)
        XCTAssertTrue(persistence.hasUnsavedChanges)
        XCTAssertTrue(persistence.isSaving)
        var flushed = false
        let waiter = Task { flushed = await persistence.flush() }
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(flushed)
        await probe.release()
        await waiter.value
        let writes = await probe.values
        XCTAssertEqual(writes, [1, 3])
        XCTAssertTrue(flushed)
        XCTAssertFalse(persistence.isSaving)
        XCTAssertFalse(persistence.hasUnsavedChanges)
    }

    func testOlderFailureCannotOverrideTheLatestSuccessfulWrite() async throws {
        let probe = WriteProbe(failFirst: true)
        let persistence = JSONPersistence(store: JSONFileStore<Int>(fileName: "state.json", directory: directory), write: probe.save)
        persistence.save(1)
        try await waitForFirstWrite(probe)
        persistence.save(2)
        await probe.release()
        let saved = await persistence.flush()
        XCTAssertTrue(saved)
        XCTAssertNil(persistence.error)
        let values = await probe.values
        XCTAssertEqual(values, [1, 2])
    }

    func testCancellingAFlushWaiterDoesNotCancelTheWrite() async throws {
        let probe = WriteProbe()
        let persistence = JSONPersistence(store: JSONFileStore<Int>(fileName: "state.json", directory: directory), write: probe.save)
        persistence.save(1)
        try await waitForFirstWrite(probe)
        let waiter = Task { await persistence.flush() }
        waiter.cancel()
        XCTAssertTrue(persistence.hasUnsavedChanges)
        await probe.release()
        let saved = await waiter.value
        XCTAssertTrue(saved)
        XCTAssertFalse(persistence.hasUnsavedChanges)
    }

    func testLargeEncodingRunsOffMainAndAllowsUIHeartbeats() async throws {
        let file = JSONFileStore<SlowPayload>(fileName: "large.json", directory: directory)
        var heartbeats = 0
        let ticker = Task {
            while !Task.isCancelled {
                heartbeats += 1
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
        defer { ticker.cancel() }
        let payload = SlowPayload(text: String(repeating: "x", count: 8_000_000))
        try await file.save(payload)
        XCTAssertGreaterThan(heartbeats, 5)
        XCTAssertEqual(try file.load()?.text.count, 8_000_000)
        print("Background JSON encoding: \(heartbeats) UI heartbeats during the write")
    }

    func testRapidFavoriteChangesAndClearPersistTheNewestState() async {
        let favorites = FavoritesStore(directory: directory)
        for index in 0..<500 { favorites.add(name: "package-\(index)", kind: .formula) }
        await Task.yield()
        favorites.clear()
        favorites.add(name: "final-package", kind: .cask)
        let saved = await favorites.flushPersistence()
        XCTAssertTrue(saved)
        let restored = FavoritesStore(directory: directory)
        XCTAssertEqual(restored.favorites.map(\.name), ["final-package"])
        XCTAssertEqual(restored.favorites.first?.kind, .cask)
    }

    func testLargeHistoryReloadsOnlyTheLatestHundredEntries() async {
        let history = HistoryStore(directory: directory)
        for index in 0..<140 {
            history.add(HistoryEntry(kind: .install, status: .success, title: "entry-\(index)",
                                     stdout: String(repeating: "output ", count: 5_000)))
        }
        let saved = await history.flushPersistence()
        XCTAssertTrue(saved)
        let restored = HistoryStore(directory: directory)
        XCTAssertEqual(restored.entries.count, 100)
        XCTAssertEqual(restored.entries.first?.title, "entry-139")
        XCTAssertEqual(restored.entries.last?.title, "entry-40")
    }

    private func waitForFirstWrite(_ probe: WriteProbe) async throws {
        let deadline = Date().addingTimeInterval(3)
        while await !probe.isWaiting, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        let waiting = await probe.isWaiting
        XCTAssertTrue(waiting)
    }
}

private actor WriteProbe {
    private(set) var values: [Int] = []
    private var continuation: CheckedContinuation<Void, Never>?
    private let failFirst: Bool
    var isWaiting: Bool { continuation != nil }

    init(failFirst: Bool = false) { self.failFirst = failFirst }

    func save(_ value: Int) async throws {
        values.append(value)
        if values.count == 1 {
            await withCheckedContinuation { continuation = $0 }
            if failFirst { throw CocoaError(.fileWriteNoPermission) }
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private struct SlowPayload: Codable, Sendable {
    let text: String

    func encode(to encoder: any Encoder) throws {
        XCTAssertFalse(Thread.isMainThread, "JSON encoding must not block the UI thread")
        Thread.sleep(forTimeInterval: 0.15)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
    }
}
