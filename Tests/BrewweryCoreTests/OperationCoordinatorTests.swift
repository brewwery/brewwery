import XCTest
@testable import BrewweryCore
import BrewweryTestSupport

@MainActor
final class OperationCoordinatorTests: XCTestCase {
    private var fake: FakeBrew!
    private var coordinator: OperationCoordinator!

    /// Built per test rather than in `setUp` so both the double and the coordinator are
    /// created on the main actor the coordinator is isolated to.
    private func startFakeHomebrew() throws {
        let double = try FakeBrew()
        fake = double
        coordinator = OperationCoordinator(client: double.makeClient())
        addTeardownBlock { double.cleanUp() }
    }

    func testPublishesLiveOutputAndASuccessfulOutcome() async throws {
        try startFakeHomebrew()
        let outcome = try await coordinator.run(.cleanup, kind: .cleanup)

        guard case .completed(let stdout, _) = outcome else {
            return XCTFail("expected a completed outcome")
        }
        XCTAssertTrue(stdout.contains("==> second"))

        let progress = try XCTUnwrap(coordinator.progress)
        XCTAssertEqual(progress.status, .success)
        XCTAssertEqual(progress.command, "brew cleanup")
        XCTAssertEqual(progress.timeoutSeconds, 30 * 60)
        XCTAssertFalse(progress.lines.isEmpty)
        XCTAssertTrue(progress.lines.contains { $0.stream == .stderr })
    }

    /// Two mutating Homebrew commands must never run at once.
    func testRefusesASecondMutatingOperationWhileOneIsRunning() async throws {
        try startFakeHomebrew()
        let first = Task { try await coordinator.run(.upgrade(.init(name: "redis", kind: .formula)), kind: .upgrade, target: "redis") }
        _ = await fake.waitForGrandchildPID()

        do {
            _ = try await coordinator.run(.cleanup, kind: .cleanup)
            XCTFail("expected the second operation to be refused")
        } catch {
            XCTAssertEqual(error.code, .operationInProgress)
        }

        await coordinator.cancel()
        _ = try? await first.value
    }

    func testCancellationSurfacesAsACancelledOutcomeAndStatus() async throws {
        try startFakeHomebrew()
        let run = Task { try await coordinator.run(.upgrade(.init(name: "redis", kind: .formula)), kind: .upgrade, target: "redis") }
        _ = await fake.waitForGrandchildPID()

        await coordinator.cancel()
        XCTAssertTrue(coordinator.isCancelling)

        let outcome = try await run.value

        XCTAssertEqual(outcome.error?.code, .operationCancelled)
        XCTAssertEqual(coordinator.progress?.status, .cancelled)
        XCTAssertFalse(coordinator.isCancelling)
    }

    func testSuccessfulOperationDismissesItselfButFailuresStay() async throws {
        let double = try FakeBrew()
        addTeardownBlock { double.cleanUp() }
        let quick = OperationCoordinator(client: double.makeClient(), successDismissDelay: .milliseconds(200))

        _ = try await quick.run(.cleanup, kind: .cleanup)
        XCTAssertEqual(quick.progress?.status, .success)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertNil(quick.progress, "a successful operation should close its panel")

        let run = Task { try await quick.run(.upgrade(.init(name: "redis", kind: .formula)), kind: .upgrade) }
        _ = await double.waitForGrandchildPID()
        await quick.cancel()
        _ = try await run.value
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(quick.progress?.status, .cancelled, "a cancelled operation must stay visible")
    }

    func testClearDismissesOnlyFinishedOperations() async throws {
        try startFakeHomebrew()
        _ = try await coordinator.run(.cleanup, kind: .cleanup)
        XCTAssertNotNil(coordinator.progress)

        coordinator.clear()

        XCTAssertNil(coordinator.progress)
    }

    func testValidationFailureLeavesNoProgressPanelBehind() async throws {
        try startFakeHomebrew()
        do {
            _ = try await coordinator.run(.install(.init(name: "bad name", kind: .formula)), kind: .install)
            XCTFail("expected validation to fail")
        } catch {
            XCTAssertEqual(error.code, .invalidPackageName)
        }

        XCTAssertNil(coordinator.progress)
    }
}
