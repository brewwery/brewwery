import XCTest
@testable import BrewweryCore
import BrewweryTestSupport

final class ScheduledUpgradeScheduleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstRunIsDue() {
        XCTAssertTrue(ScheduledUpgradeSchedule.isDue(lastRun: nil, interval: .daily, now: now))
    }

    /// launchd wakes the agent hourly, so a daily run that started at 09:00:30 must be due
    /// again at the 09:00 wake-up the next day, not slip to 10:00.
    func testDueWithinToleranceOfTheInterval() {
        let interval = ScheduledUpgradeInterval.daily.duration
        let tolerance = ScheduledUpgradeSchedule.tolerance

        XCTAssertTrue(ScheduledUpgradeSchedule.isDue(lastRun: now.addingTimeInterval(-(interval - tolerance)), interval: .daily, now: now))
        XCTAssertFalse(ScheduledUpgradeSchedule.isDue(lastRun: now.addingTimeInterval(-(interval - tolerance) + 1), interval: .daily, now: now))
    }

    func testIntervalsAreIndependent() {
        let sevenHoursAgo = now.addingTimeInterval(-7 * 3600)

        XCTAssertTrue(ScheduledUpgradeSchedule.isDue(lastRun: sevenHoursAgo, interval: .sixHours, now: now))
        XCTAssertFalse(ScheduledUpgradeSchedule.isDue(lastRun: sevenHoursAgo, interval: .twelveHours, now: now))
        XCTAssertFalse(ScheduledUpgradeSchedule.isDue(lastRun: now.addingTimeInterval(-6 * 86_400), interval: .weekly, now: now))
    }

    /// A clock set back must not stall upgrades until it catches up with the stored run.
    func testLastRunInTheFutureIsDue() {
        XCTAssertTrue(ScheduledUpgradeSchedule.isDue(lastRun: now.addingTimeInterval(86_400), interval: .weekly, now: now))
        XCTAssertFalse(ScheduledUpgradeSchedule.isDue(lastRun: now.addingTimeInterval(60), interval: .daily, now: now))
    }
}

final class MutationLockTests: XCTestCase {
    private var directory: URL!
    private var lock: MutationLock!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("brewwery-lock-\(UUID().uuidString)")
        lock = MutationLock(url: directory.appendingPathComponent("nested/homebrew-mutation.lock"))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    func testOnlyOneHolderAtATime() throws {
        let first = try XCTUnwrap(lock.tryAcquire())
        XCTAssertNil(lock.tryAcquire(), "a second descriptor must not take a held lock")

        first.release()
        XCTAssertNotNil(lock.tryAcquire())
    }

    func testDroppingTheTokenReleasesTheLock() {
        do {
            let token = lock.tryAcquire()
            XCTAssertNotNil(token)
        }
        XCTAssertNotNil(lock.tryAcquire())
    }

    /// The agent runs in another process; `flock` is what makes the two see each other.
    func testLockIsVisibleToAnotherProcess() throws {
        let token = try XCTUnwrap(lock.tryAcquire())
        XCTAssertNotEqual(try lockProbeStatus(), 0, "another process must not get the lock while it is held")

        token.release()
        XCTAssertEqual(try lockProbeStatus(), 0)
    }

    /// `/usr/bin/shlock` is no use here (it is PID-file based), so the probe uses `flock` via perl.
    private func lockProbeStatus() throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", "use Fcntl ':flock'; open(my $f, '<', $ARGV[0]) or exit 2; exit(flock($f, LOCK_EX | LOCK_NB) ? 0 : 1)", lock.url.path]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

final class MutationLockRunnerTests: XCTestCase {
    private var fake: FakeBrew!
    private var lock: MutationLock!

    override func setUpWithError() throws {
        fake = try FakeBrew(overrides: #"[ "$1" = "upgrade" ] && { echo "==> Upgraded"; exit 0; }"#)
        lock = MutationLock(url: fake.directory.appendingPathComponent("homebrew-mutation.lock"))
    }

    override func tearDown() {
        fake.cleanUp()
    }

    func testMutationFailsWhileAnotherProcessHoldsTheLock() async throws {
        let client = HomebrewClient(detector: fake.makeDetector(), mutationLock: lock)
        let token = try XCTUnwrap(lock.tryAcquire())

        do {
            _ = try await client.updateMetadata()
            XCTFail("a mutation must not run while the lock is held")
        } catch {
            XCTAssertEqual(error.code, .homebrewBusy)
        }
        do {
            _ = try await client.stream(.upgradeAll, kind: .upgrade, id: UUID())
            XCTFail("a streamed mutation must not start while the lock is held")
        } catch {
            XCTAssertEqual(error.code, .homebrewBusy)
        }
        // Reads never take the lock.
        try fake.setOutdated(formulae: ["wget"])
        let outdated = try await client.outdated()
        XCTAssertEqual(outdated.map(\.name), ["wget"])

        token.release()
        _ = try await client.updateMetadata()
    }

    func testRunnerReleasesTheLockWhenTheMutationEnds() async throws {
        let client = HomebrewClient(detector: fake.makeDetector(), mutationLock: lock)

        _ = try await client.updateMetadata()
        XCTAssertNotNil(lock.tryAcquire(), "a finished buffered mutation must release the lock")

        let events = try await client.stream(.upgradeAll, kind: .upgrade, id: UUID())
        for await _ in events {}
        XCTAssertNotNil(lock.tryAcquire(), "a finished streamed mutation must release the lock")
    }
}

final class ScheduledUpgradeInboxTests: XCTestCase {
    private var directory: URL!
    private var inbox: ScheduledUpgradeInbox!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("brewwery-inbox-\(UUID().uuidString)")
        inbox = ScheduledUpgradeInbox(directory: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func entry(_ title: String) -> HistoryEntry {
        HistoryEntry(kind: .upgrade, status: .success, title: title)
    }

    func testCollectReturnsDeliveriesInOrderExactlyOnce() throws {
        try inbox.deliver([entry("first"), entry("second")], at: Date(timeIntervalSince1970: 100))
        try inbox.deliver([entry("third")], at: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(inbox.collect().map(\.title), ["first", "second", "third"])
        XCTAssertEqual(inbox.collect(), [], "an imported delivery must not be imported again")
    }

    func testUnreadableDeliveryIsKeptAsideAndSkipped() throws {
        try inbox.deliver([entry("good")], at: Date(timeIntervalSince1970: 200))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{not json".utf8).write(to: directory.appendingPathComponent("000000000000100-broken.json"))

        XCTAssertEqual(inbox.collect().map(\.title), ["good"])
        XCTAssertEqual(inbox.collect(), [])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(remaining, ["000000000000100-broken.json.unreadable"], "kept for diagnosis, never retried")
    }

    func testCollectOnAMissingDirectoryIsEmpty() {
        XCTAssertEqual(inbox.collect(), [])
    }
}

final class ScheduledUpgradeJobTests: XCTestCase {
    private var fake: FakeBrew!
    private var calls: URL { fake.directory.appendingPathComponent("calls.log") }

    override func tearDown() {
        fake?.cleanUp()
    }

    /// Records every subcommand; `upgrade` finishes at once instead of the double's 120 s.
    private func makeFake(extra: String = "") throws -> FakeBrew {
        fake = try FakeBrew(overrides: """
        echo "$1" >> "$(dirname "$0")/calls.log"
        \(extra)
        [ "$1" = "upgrade" ] && { echo "==> Upgrading wget 1.0.0 -> 1.1.0"; exit 0; }
        """)
        return fake
    }

    private func recordedCalls() -> [String] {
        ((try? String(contentsOf: calls, encoding: .utf8)) ?? "")
            .split(separator: "\n").map(String.init)
            .filter { $0 == "update" || $0 == "upgrade" }
    }

    func testNothingOutdatedProducesNoEntryAndNoUpgrade() async throws {
        let fake = try makeFake()
        try fake.setOutdated()

        let entries = await ScheduledUpgradeJob.run(client: fake.makeClient())

        XCTAssertEqual(entries, [])
        XCTAssertEqual(recordedCalls(), ["update"])
    }

    func testPinnedOnlyCountsAsUpToDate() async throws {
        let fake = try makeFake()
        try fake.setOutdated(formulae: ["postgresql@17"], pinned: ["postgresql@17"])

        let entries = await ScheduledUpgradeJob.run(client: fake.makeClient())

        XCTAssertEqual(entries, [])
        XCTAssertEqual(recordedCalls(), ["update"])
    }

    func testOutdatedPackagesAreUpgradedAfterUpdate() async throws {
        let fake = try makeFake()
        try fake.setOutdated(formulae: ["wget", "postgresql@17"], casks: ["firefox"], pinned: ["postgresql@17"])

        let entries = await ScheduledUpgradeJob.run(client: fake.makeClient())

        XCTAssertEqual(recordedCalls(), ["update", "upgrade"])
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entry.status, .success)
        XCTAssertEqual(entry.kind, .upgrade)
        XCTAssertEqual(entry.command, "brew update && brew upgrade")
        XCTAssertEqual(entry.details, "wget 1.0.0 → 1.1.0\nfirefox 1.0.0 → 1.1.0", "pinned formulae are not reported as upgraded")
        XCTAssertTrue(entry.stdout?.contains("Upgrading wget") == true)
    }

    func testFailedUpdateIsReportedAndSkipsTheUpgrade() async throws {
        let fake = try makeFake(extra: #"[ "$1" = "update" ] && { echo "fatal: unable to access github.com" >&2; exit 1; }"#)
        try fake.setOutdated(formulae: ["wget"])

        let entries = await ScheduledUpgradeJob.run(client: fake.makeClient())

        XCTAssertEqual(recordedCalls(), ["update"])
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.status, .failed)
        XCTAssertEqual(entry.kind, .brewUpdate)
        XCTAssertEqual(entry.stderr, "fatal: unable to access github.com")
    }

    func testFailedUpgradeIsReported() async throws {
        let fake = try makeFake(extra: #"[ "$1" = "upgrade" ] && { echo "Error: sudo: a password is required" >&2; exit 1; }"#)
        try fake.setOutdated(casks: ["docker"])

        let entries = await ScheduledUpgradeJob.run(client: fake.makeClient())

        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.status, .failed)
        XCTAssertEqual(entry.error?.code, .brewCommandFailed)
        XCTAssertEqual(entry.stderr, "Error: sudo: a password is required")
        XCTAssertEqual(entry.details, "docker 1.0.0 → 1.1.0")
    }
}
