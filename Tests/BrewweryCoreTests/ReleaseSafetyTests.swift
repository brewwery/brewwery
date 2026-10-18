import XCTest
@testable import BrewweryCore
import BrewweryTestSupport

final class ReleaseSafetyTests: XCTestCase {
    func testOptionShapedNamesAreRejected() {
        let commands: [HomebrewCommand] = [
            .service(action: .stop, name: "--all"), .pin(formula: "--help"),
            .install(.init(name: "--cask", kind: .formula)), .uninstall(.init(name: "--force", kind: .cask)),
            .addTap(name: "--custom/tools"), .removeTap(name: "owner/.."), .formulaInfo(name: "./redis"),
            .searchFormulae(query: "--eval")
        ]
        for command in commands { XCTAssertThrowsError(try command.arguments(), "\(command)") }
    }

    func testBufferedCancellationTerminatesTheProcessGroupAndReleasesTheSlot() async throws {
        let fake = try FakeBrew()
        defer { fake.cleanUp() }
        let runner = HomebrewRunner(detector: fake.makeDetector())
        let task = Task { try await runner.run(.upgradeAll) }
        let reported = await fake.waitForGrandchildPID()
        let pid = try XCTUnwrap(reported)
        task.cancel()
        do { _ = try await task.value; XCTFail("expected cancellation") }
        catch { XCTAssertEqual((error as? BrewweryError)?.code, .operationCancelled) }
        let gone = await FakeBrew.waitUntilGone(pid)
        XCTAssertTrue(gone)
        let next = try await runner.run(.pin(formula: "redis"))
        XCTAssertTrue(next.success)
    }

    func testBufferedTimeoutTerminatesTheProcessGroup() async throws {
        let fake = try FakeBrew()
        defer { fake.cleanUp() }
        let runner = HomebrewRunner(detector: fake.makeDetector(), bufferedTimeout: .milliseconds(400))
        do { _ = try await runner.run(.upgradeAll); XCTFail("expected timeout") }
        catch { XCTAssertEqual(error.code, .operationTimeout) }
        let reported = await fake.waitForGrandchildPID()
        let pid = try XCTUnwrap(reported)
        let gone = await FakeBrew.waitUntilGone(pid)
        XCTAssertTrue(gone)
    }

    func testBufferedOutputLimitIsAnErrorNotTruncatedJSON() async throws {
        let fake = try FakeBrew()
        defer { fake.cleanUp() }
        let runner = HomebrewRunner(detector: fake.makeDetector(), maximumBufferedBytes: 8)
        do { _ = try await runner.run(.listFormulaeFallback); XCTFail("expected limit error") }
        catch {
            XCTAssertEqual(error.code, .brewCommandFailed)
            XCTAssertTrue(error.message.contains("safety limit"))
        }
    }

    func testSynchronousPathProbeHasADeadline() throws {
        let fake = try FakeBrew(overrides: "if [ \"$1\" = --version ]; then /bin/sleep 120; fi")
        defer { fake.cleanUp() }
        let start = Date()
        XCTAssertThrowsError(try ProcessOutput.capture(executablePath: fake.executable.path, arguments: ["--version"], environment: [:], timeoutSeconds: 0.2)) { error in
            XCTAssertEqual((error as? BrewweryError)?.code, .operationTimeout)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testLowLevelGuardIncludesBufferedAndStreamingMutations() async throws {
        let fake = try FakeBrew()
        defer { fake.cleanUp() }
        let runner = HomebrewRunner(detector: fake.makeDetector())
        let first = Task { try await runner.run(.upgradeAll) }
        _ = await fake.waitForGrandchildPID()
        do { _ = try await runner.stream(.cleanup, kind: .cleanup, id: UUID()); XCTFail("expected lock") }
        catch { XCTAssertEqual(error.code, .operationInProgress) }
        let read = try await runner.run(.leaves)
        XCTAssertTrue(read.success, "reads remain available")
        first.cancel()
        _ = try? await first.value
    }

    func testSlowStreamConsumerRetainsTerminalEventAndBoundedSnapshot() async throws {
        let fake = try FakeBrew(overrides: """
        if [ "$1" = cleanup ]; then
          /usr/bin/yes output | /usr/bin/head -c 5000000
          /usr/bin/yes warning | /usr/bin/head -c 5000000 >&2
          echo END-OF-OUTPUT
          exit 0
        fi
        """)
        defer { fake.cleanUp() }
        let runner = HomebrewRunner(detector: fake.makeDetector())
        let id = UUID()
        let events = try await runner.stream(.cleanup, kind: .cleanup, id: id)
        let deadline = Date().addingTimeInterval(10)
        while await runner.isRunning(id), Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        let stillRunning = await runner.isRunning(id)
        XCTAssertFalse(stillRunning)
        if stillRunning { await runner.cancel(id) }
        var count = 0
        var terminalCount = 0
        for await event in events {
            count += 1
            if case .completed(let stdout, let stderr, _, _) = event {
                terminalCount += 1
                XCTAssertTrue(stdout.contains("END-OF-OUTPUT"))
                XCTAssertLessThan(stdout.count, 210_000)
                XCTAssertLessThan(stderr.count, 210_000)
            }
        }
        XCTAssertEqual(terminalCount, 1)
        XCTAssertLessThanOrEqual(count, 128)
    }

    func testPipeDecoderPreservesSplitUnicode() {
        let text = "Made Büro 日本語"
        var decoder = PipeTextDecoder()
        var decoded = ""
        for byte in text.utf8 { decoded += decoder.append(Data([byte])) }
        decoded += decoder.finish()
        XCTAssertEqual(decoded, text)
    }
}
