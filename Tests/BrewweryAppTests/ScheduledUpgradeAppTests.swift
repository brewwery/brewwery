import BrewweryCore
import BrewweryTestSupport
import XCTest
@testable import Brewwery

@MainActor
private final class FakeScheduledUpgradeService: ScheduledUpgradeService {
    var status: ScheduledUpgradeServiceStatus = .notRegistered
    var registerError: (any Error)?
    var statusAfterRegister: ScheduledUpgradeServiceStatus = .enabled
    private(set) var registrations = 0
    private(set) var unregistrations = 0

    func register() throws {
        if let registerError { throw registerError }
        registrations += 1
        status = statusAfterRegister
    }

    func unregister() throws {
        unregistrations += 1
        status = .notRegistered
    }

    func openLoginItemsSettings() {}
}

@MainActor
final class ScheduledUpgradeControllerTests: XCTestCase {
    private var suiteName = ""
    private var settings: SettingsStore!
    private var service: FakeScheduledUpgradeService!

    override func setUp() async throws {
        suiteName = "brewwery-schedule-tests-\(UUID().uuidString)"
        settings = SettingsStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suiteName)))
        service = FakeScheduledUpgradeService()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func makeController() -> ScheduledUpgradeController {
        ScheduledUpgradeController(settings: settings, service: service, inbox: nil)
    }

    /// Turning the schedule on must not upgrade anything straight away.
    func testEnableRegistersAndStartsTheIntervalNow() {
        let controller = makeController()
        let before = Date()

        controller.enable()

        XCTAssertEqual(service.registrations, 1)
        XCTAssertTrue(settings.scheduledUpgradesEnabled)
        XCTAssertEqual(controller.status, .enabled)
        let lastRun = try? XCTUnwrap(settings.scheduledUpgradeLastRun)
        XCTAssertGreaterThanOrEqual(lastRun ?? .distantPast, before)
        XCTAssertFalse(ScheduledUpgradeSchedule.isDue(lastRun: lastRun, interval: .sixHours, now: Date()))
    }

    func testFailedRegistrationLeavesTheScheduleOff() {
        service.registerError = CocoaError(.featureUnsupported)
        let controller = makeController()

        controller.enable()

        XCTAssertFalse(settings.scheduledUpgradesEnabled)
        XCTAssertNotNil(controller.lastError)
    }

    func testPendingApprovalIsReported() {
        service.statusAfterRegister = .requiresApproval
        let controller = makeController()

        controller.enable()

        XCTAssertTrue(settings.scheduledUpgradesEnabled)
        XCTAssertEqual(controller.status, .requiresApproval)
    }

    func testDisableUnregisters() {
        let controller = makeController()
        controller.enable()

        controller.disable()

        XCTAssertFalse(settings.scheduledUpgradesEnabled)
        XCTAssertEqual(service.unregistrations, 1)
        XCTAssertEqual(controller.status, .notRegistered)
    }

    func testReconcileFollowsThePreference() {
        settings.scheduledUpgradesEnabled = true
        let controller = makeController()
        controller.reconcile()
        XCTAssertEqual(service.registrations, 1, "enabled but not registered → register")

        settings.scheduledUpgradesEnabled = false
        controller.reconcile()
        XCTAssertEqual(service.unregistrations, 1, "registered but disabled → unregister")

        controller.reconcile()
        XCTAssertEqual(service.registrations + service.unregistrations, 2, "in agreement → nothing to do")
    }

    func testWithoutAServiceTheFeatureIsUnavailable() {
        let controller = ScheduledUpgradeController(settings: settings, service: nil, inbox: nil)

        controller.enable()

        XCTAssertFalse(controller.isAvailable)
        XCTAssertFalse(settings.scheduledUpgradesEnabled)
    }
}

@MainActor
final class ScheduledUpgradeAgentTests: XCTestCase {
    private var harness: AppTestHarness!
    private var inbox: ScheduledUpgradeInbox!
    private var lock: MutationLock!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private var settings: SettingsStore { harness.environment.settings }
    private var upgradeCalls: URL { harness.fake.directory.appendingPathComponent("upgrades.log") }
    /// What another process saw when it tried the mutation lock during `brew upgrade`.
    private var lockProbe: URL { harness.fake.directory.appendingPathComponent("lock-probe.log") }

    override func setUp() async throws {
        // `update` and `upgrade` also ask, from a separate process, whether the mutation lock is free.
        harness = try AppTestHarness(overrides: """
        if [ "$1" = "update" ] || [ "$1" = "upgrade" ]; then
          state="$(/usr/bin/perl -e 'use Fcntl qw(:flock); open(my $f, ">>", $ARGV[0]) or die; print flock($f, LOCK_EX | LOCK_NB) ? "free" : "busy"' "$(dirname "$0")/state/homebrew-mutation.lock")"
          echo "$1 $state" >> "$(dirname "$0")/lock-probe.log"
        fi
        if [ "$1" = "upgrade" ]; then
          echo upgrade >> "$(dirname "$0")/upgrades.log"
          echo "==> Upgraded"; exit 0
        fi
        """)
        try harness.fake.setOutdated(formulae: ["wget"])
        inbox = ScheduledUpgradeInbox(directory: harness.directory.appendingPathComponent("inbox"))
        lock = MutationLock(url: harness.directory.appendingPathComponent("homebrew-mutation.lock"))
        settings.scheduledUpgradesEnabled = true
        settings.scheduledUpgradeInterval = .daily
        settings.scheduledUpgradeLastRun = now.addingTimeInterval(-2 * 86_400)
    }

    override func tearDown() async throws {
        await harness.tearDown()
    }

    private func runAgent() async -> Int32 {
        await ScheduledUpgradeAgent.run(settings: settings, lock: lock, inbox: inbox, client: harness.fake.makeClient(), now: { self.now })
    }

    private var upgradeCount: Int {
        ((try? String(contentsOf: upgradeCalls, encoding: .utf8)) ?? "").split(separator: "\n").count
    }

    func testDueRunUpgradesAndLeavesTheResultForTheApp() async {
        let status = await runAgent()

        XCTAssertEqual(status, 0)
        XCTAssertEqual(upgradeCount, 1)
        XCTAssertEqual(settings.scheduledUpgradeLastRun, now)
        XCTAssertEqual(inbox.collect().map(\.status), [.success])
        XCTAssertNotNil(lock.tryAcquire(), "the agent must release the lock when it exits")
    }

    /// An app opened mid-run must see Homebrew as busy for the whole job, `brew update` included.
    func testLockIsHeldForTheWholeJob() async throws {
        _ = await runAgent()

        XCTAssertEqual(try String(contentsOf: lockProbe, encoding: .utf8), "update busy\nupgrade busy\n")
    }

    /// A result that could not be saved must not count as a run, or the user never sees it.
    func testUndeliverableResultIsRetriedOnTheNextStart() async throws {
        let lastRun = try XCTUnwrap(settings.scheduledUpgradeLastRun)
        // A file where the inbox directory should be makes every delivery fail.
        try FileManager.default.createDirectory(at: harness.directory, withIntermediateDirectories: true)
        try Data().write(to: inbox.directory)

        let status = await runAgent()

        XCTAssertEqual(status, 1)
        XCTAssertEqual(settings.scheduledUpgradeLastRun, lastRun)
        XCTAssertNotNil(lock.tryAcquire(), "the agent must release the lock when it fails")
    }

    func testDisabledScheduleDoesNothing() async {
        settings.scheduledUpgradesEnabled = false

        _ = await runAgent()

        XCTAssertEqual(upgradeCount, 0)
        XCTAssertEqual(inbox.collect(), [])
    }

    func testRunBeforeTheIntervalElapsedDoesNothing() async {
        let lastRun = now.addingTimeInterval(-3600)
        settings.scheduledUpgradeLastRun = lastRun

        _ = await runAgent()

        XCTAssertEqual(upgradeCount, 0)
        XCTAssertEqual(settings.scheduledUpgradeLastRun, lastRun)
    }

    /// The app holds the lock while it changes Homebrew; the agent must neither overlap it
    /// nor count the skipped run, so the next hourly start tries again.
    func testHeldLockDefersTheRunWithoutRecordingIt() async throws {
        let lastRun = try XCTUnwrap(settings.scheduledUpgradeLastRun)
        let appOperation = try XCTUnwrap(lock.tryAcquire())

        _ = await runAgent()

        XCTAssertEqual(upgradeCount, 0)
        XCTAssertEqual(settings.scheduledUpgradeLastRun, lastRun)
        appOperation.release()
    }

    func testAppImportsTheAgentsResultIntoHistoryOnce() async throws {
        let service = FakeScheduledUpgradeService()
        let environment = AppEnvironment(
            client: harness.fake.makeClient(),
            settings: settings,
            history: HistoryStore(directory: harness.directory.appendingPathComponent("import")),
            favorites: FavoritesStore(directory: harness.directory.appendingPathComponent("import")),
            updateDriver: nil,
            scheduledUpgrades: ScheduledUpgradeController(settings: settings, service: service, inbox: inbox)
        )
        try inbox.deliver([
            HistoryEntry(kind: .upgrade, status: .success, title: "Scheduled upgrade finished", timestamp: now)
        ])

        await environment.importScheduledUpgradeResults()
        await environment.importScheduledUpgradeResults()

        XCTAssertEqual(environment.history.entries.map(\.title), ["Scheduled upgrade finished"])
        _ = await environment.flushPersistence()
    }
}
