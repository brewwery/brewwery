import XCTest
@testable import BrewweryCore
import BrewweryTestSupport

/// End-to-end tests for the process layer, driven by the `FakeBrew` test double.
///
/// These cover the behaviours that only show up against a real process: trimming, exit-code
/// handling, the `needless argument` fallback, live streaming, safety-timeout wiring and —
/// most importantly — that cancellation kills the whole process group.
final class HomebrewRunnerTests: XCTestCase {
    private var fake: FakeBrew!
    private var runner: HomebrewRunner!

    override func setUpWithError() throws {
        fake = try FakeBrew()
        runner = HomebrewRunner(detector: HomebrewDetector(customPath: fake.executable.path))
    }

    override func tearDown() {
        fake.cleanUp()
    }

    // MARK: - Buffered execution

    func testCapturesAndTrimsStdout() async throws {
        let output = try await runner.run(.leaves)

        XCTAssertTrue(output.success)
        XCTAssertEqual(output.statusCode, 0)
        // Rust trimmed both ends; the parser is written against trimmed text.
        XCTAssertEqual(output.stdout, "redis  \npostgresql@17")
        XCTAssertEqual(PackageParser.parseNameLines(output.stdout), ["redis", "postgresql@17"])
    }

    func testNonZeroExitRaisesCommandFailedCarryingStderr() async {
        do {
            _ = try await runner.run(.outdated)
            XCTFail("expected the command to fail")
        } catch {
            XCTAssertEqual(error.code, .brewCommandFailed)
            XCTAssertEqual(error.raw, "boom: could not reach formulae.brew.sh")
        }
    }

    func testPermissiveRunKeepsOutputFromAFailingCommand() async throws {
        let output = try await runner.runPermissive(.doctor)

        XCTAssertFalse(output.success)
        XCTAssertTrue(output.stdout.contains("Warning: Broken symlinks were found"))
    }

    /// `brew doctor` exits 1 whenever it reports anything, so the normal runner must not
    /// treat that as a failure.
    func testDoctorToleratesItsNonZeroExit() async throws {
        let output = try await runner.run(.doctor)

        XCTAssertFalse(output.success)
        XCTAssertEqual(DoctorParser.parse(output.stdout).count, 1)
    }

    /// Homebrew 5 rejects `--json=v2` for `brew list`; only that specific message triggers
    /// the legacy argument fallback.
    func testFallsBackWhenHomebrewRejectsTheJSONArgument() async throws {
        let output = try await runner.run(.listFormulae, fallback: .listFormulaeFallback)

        let formulae = try PackageParser.parseFormulae(json: output.stdout)
        XCTAssertEqual(formulae.map(\.name), ["wget"])
        XCTAssertEqual(formulae[0].installedVersion, "1.25.0")
    }

    func testDoesNotFallBackForUnrelatedFailures() async {
        do {
            _ = try await runner.run(.outdated, fallback: .leaves)
            XCTFail("expected the command to fail")
        } catch {
            XCTAssertEqual(error.code, .brewCommandFailed)
        }
    }

    func testValidationFailsBeforeAnythingIsSpawned() async {
        do {
            _ = try await runner.run(.install(.init(name: "redis; rm -rf /", kind: .formula)))
            XCTFail("expected validation to reject the identifier")
        } catch {
            XCTAssertEqual(error.code, .invalidPackageName)
        }
    }

    // MARK: - Streaming

    func testStreamsLiveOutputAndFinishesWithACompletedEvent() async throws {
        let events = try await runner.stream(.cleanup, kind: .cleanup, id: UUID())

        var chunks: [String] = []
        var terminal: OperationEvent?
        var sawStarted = false

        for await event in events {
            switch event {
            case .started: sawStarted = true
            case .output(_, let chunk, _): chunks.append(chunk)
            case .completed, .failed: terminal = event
            }
        }

        XCTAssertTrue(sawStarted)
        // Output arrives while the command is still running, not only at the end.
        XCTAssertGreaterThanOrEqual(chunks.count, 2)
        XCTAssertTrue(chunks.joined().contains("==> first"))

        guard case .completed(let stdout, let stderr, let status, _) = terminal else {
            return XCTFail("expected a completed terminal event, got \(String(describing: terminal))")
        }
        XCTAssertEqual(status, 0)
        XCTAssertTrue(stdout.contains("==> second"))
        XCTAssertEqual(stderr, "a warning")
    }

    /// The central cancellation guarantee: `brew` forks helpers, and terminating only the
    /// direct child would orphan them. Brewwery signals the whole process group.
    func testCancellationTerminatesTheChildAndItsGrandchildren() async throws {
        let id = UUID()
        let events = try await runner.stream(
            .upgrade(.init(name: "redis", kind: .formula)),
            kind: .upgrade,
            id: id
        )

        let grandchild = await fake.waitForGrandchildPID()
        let pid = try XCTUnwrap(grandchild, "the fake brew never reported its child PID")
        XCTAssertEqual(kill(pid, 0), 0, "the grandchild should be alive before cancelling")

        let cancelled = await runner.cancel(id)
        XCTAssertTrue(cancelled)

        var terminal: OperationEvent?
        for await event in events {
            if case .output = event { continue }
            if case .started = event { continue }
            terminal = event
        }

        guard case .failed(_, _, _, let error, _) = terminal else {
            return XCTFail("expected a failed terminal event, got \(String(describing: terminal))")
        }
        XCTAssertEqual(error.code, .operationCancelled)
        XCTAssertEqual(error.message, "brew upgrade redis was cancelled.")

        let gone = await FakeBrew.waitUntilGone(pid)
        XCTAssertTrue(gone, "the grandchild process survived cancellation")
    }

    func testCancellingAnUnknownOperationReportsNoSignalSent() async {
        let sent = await runner.cancel(UUID())

        XCTAssertFalse(sent)
    }

    func testCancellingAFinishedOperationReportsNoSignalSent() async throws {
        let id = UUID()
        let events = try await runner.stream(.cleanup, kind: .cleanup, id: id)
        for await _ in events {}

        let sent = await runner.cancel(id)

        XCTAssertFalse(sent)
    }

    /// Dropping the stream must not leave `brew` running in the background.
    func testAbandoningTheStreamTerminatesTheProcessGroup() async throws {
        let events = try await runner.stream(
            .upgrade(.init(name: "redis", kind: .formula)),
            kind: .upgrade,
            id: UUID()
        )

        let consumer = Task {
            for await _ in events {}
        }
        let reported = await fake.waitForGrandchildPID()
        let pid = try XCTUnwrap(reported)
        consumer.cancel()

        let gone = await FakeBrew.waitUntilGone(pid)
        XCTAssertTrue(gone, "abandoning the stream left a Homebrew process running")
    }
}
