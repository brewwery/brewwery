import XCTest
@testable import BrewweryCore
import BrewweryTestSupport

/// Parity tests for `system.rs` detection and path validation.
final class HomebrewDetectorTests: XCTestCase {
    private var fake: FakeBrew!

    override func setUpWithError() throws {
        fake = try FakeBrew()
    }

    override func tearDown() {
        fake.cleanUp()
    }

    func testValidatesAWorkingExecutable() {
        let result = HomebrewDetector.validate(path: fake.executable.path)

        XCTAssertTrue(result.valid)
        XCTAssertEqual(result.path, fake.executable.path)
        // Only the first line of `brew --version` is kept.
        XCTAssertEqual(result.version, "Homebrew 4.5.0-test")
        XCTAssertNil(result.error)
    }

    func testRejectsRelativeAndMissingPaths() {
        XCTAssertEqual(HomebrewDetector.validate(path: "").error?.code, .invalidFilePath)
        XCTAssertEqual(HomebrewDetector.validate(path: "bin/brew").error?.code, .invalidFilePath)
        XCTAssertEqual(HomebrewDetector.validate(path: "/nope/brew").error?.code, .invalidFilePath)
        XCTAssertEqual(
            HomebrewDetector.validate(path: "/nope/brew").error?.message,
            "Homebrew executable does not exist."
        )
    }

    func testRejectsDirectories() {
        let result = HomebrewDetector.validate(path: fake.directory.path)

        XCTAssertFalse(result.valid)
        XCTAssertEqual(result.error?.code, .invalidFilePath)
        XCTAssertEqual(result.error?.message, "Homebrew path must point to an executable file.")
    }

    func testRejectsNonExecutableFiles() throws {
        let file = fake.directory.appendingPathComponent("not-executable")
        try "#!/bin/sh\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)

        let result = HomebrewDetector.validate(path: file.path)

        XCTAssertFalse(result.valid)
        XCTAssertEqual(result.error?.code, .permissionDenied)
    }

    func testRejectsAnExecutableThatCannotAnswerVersion() throws {
        let file = fake.directory.appendingPathComponent("broken-brew")
        try "#!/bin/sh\necho 'nope' >&2\nexit 1\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)

        let result = HomebrewDetector.validate(path: file.path)

        XCTAssertFalse(result.valid)
        XCTAssertEqual(result.error?.code, .brewCommandFailed)
        XCTAssertEqual(result.error?.raw ?? result.error?.message, "nope")
    }

    /// Regression: the synchronous probe used to call `waitpid` itself, racing the child's
    /// own exit watcher. The second reap returned `ECHILD` with an untouched status word, so
    /// a failing `brew --version` was intermittently reported as a valid Homebrew.
    func testFailingExecutableIsRejectedEveryTime() throws {
        let file = fake.directory.appendingPathComponent("flaky-brew")
        try "#!/bin/sh\necho 'nope' >&2\nexit 1\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)

        for attempt in 1...25 {
            let result = HomebrewDetector.validate(path: file.path)
            XCTAssertFalse(result.valid, "attempt \(attempt) reported a broken executable as valid")
            XCTAssertEqual(result.error?.code, .brewCommandFailed, "attempt \(attempt)")
        }
    }

    func testTrimsSurroundingWhitespaceFromTheSuppliedPath() {
        XCTAssertTrue(HomebrewDetector.validate(path: "  \(fake.executable.path)  ").valid)
    }

    func testDetectsAValidCustomPathFirst() async {
        let detector = HomebrewDetector()
        let validation = await detector.setCustomPath(fake.executable.path)
        XCTAssertTrue(validation.valid)

        let detection = await detector.detect()

        XCTAssertTrue(detection.found)
        XCTAssertEqual(detection.path, fake.executable.path)
        XCTAssertNil(detection.error)
        // The custom path is reported first, and PATH remains the final fallback.
        XCTAssertEqual(detection.checkedPaths.first, fake.executable.path)
        XCTAssertEqual(detection.checkedPaths.last, "PATH")
        XCTAssertTrue(detection.checkedPaths.contains("/opt/homebrew/bin/brew"))
        XCTAssertTrue(detection.checkedPaths.contains("/usr/local/bin/brew"))
    }

    func testDoesNotStoreAnInvalidCustomPath() async {
        let detector = HomebrewDetector()

        let validation = await detector.setCustomPath("/definitely/not/brew")

        XCTAssertFalse(validation.valid)
        let stored = await detector.currentCustomPath()
        XCTAssertNil(stored)
    }

    func testDropsAStoredPathThatNoLongerValidates() async {
        let detector = HomebrewDetector()

        let validation = await detector.applyStoredCustomPath("/removed/brew")

        XCTAssertEqual(validation?.valid, false)
        let stored = await detector.currentCustomPath()
        XCTAssertNil(stored)
    }

    func testClearingTheCustomPathRemovesItFromTheCheckedList() async {
        let detector = HomebrewDetector(customPath: fake.executable.path)
        await detector.clearCustomPath()

        let detection = await detector.detect()

        XCTAssertFalse(detection.checkedPaths.contains(fake.executable.path))
        XCTAssertEqual(detection.checkedPaths, HomebrewDetector.standardPaths + ["PATH"])
    }

    // MARK: - Layouts and absence, reproduced on any machine

    /// A Mac with no Homebrew anywhere: no fixed location exists and `PATH` has no `brew`.
    func testReportsHomebrewNotFoundWhenNothingResolves() async {
        let detector = HomebrewDetector(
            candidatePaths: ["/nonexistent/opt/homebrew/bin/brew", "/nonexistent/usr/local/bin/brew"],
            environment: ["PATH": fake.directory.appendingPathComponent("empty").path]
        )

        let detection = await detector.detect()

        XCTAssertFalse(detection.found)
        XCTAssertNil(detection.path)
        XCTAssertEqual(detection.error?.code, .homebrewNotFound)
        XCTAssertEqual(detection.error?.message, "Homebrew was not found in /opt/homebrew, /usr/local, or PATH.")
        XCTAssertEqual(detection.checkedPaths.last, "PATH")
    }

    /// An Intel Mac: nothing under `/opt/homebrew`, Homebrew under `/usr/local`.
    func testFallsThroughToTheSecondLocationLikeAnIntelMac() async {
        let detector = HomebrewDetector(
            candidatePaths: ["/nonexistent/opt/homebrew/bin/brew", fake.executable.path],
            environment: ["PATH": "/nonexistent"]
        )

        let detection = await detector.detect()

        XCTAssertTrue(detection.found)
        XCTAssertEqual(detection.path, fake.executable.path)
    }

    /// A non-standard install that is only reachable through `PATH`.
    func testFindsHomebrewThroughPATHAsTheLastResort() async {
        let detector = HomebrewDetector(
            candidatePaths: ["/nonexistent/brew"],
            environment: ["PATH": fake.directory.path]
        )

        let detection = await detector.detect()

        XCTAssertTrue(detection.found)
        XCTAssertEqual(detection.path, fake.executable.path)
    }

    /// A saved custom path that has since been deleted must not strand the user: detection
    /// falls back to the normal locations.
    func testBrokenCustomPathFallsBackToTheStandardLocations() async {
        let detector = HomebrewDetector(
            customPath: "/deleted/brew",
            candidatePaths: [fake.executable.path],
            environment: ["PATH": "/nonexistent"]
        )

        let detection = await detector.detect()

        XCTAssertTrue(detection.found)
        XCTAssertEqual(detection.path, fake.executable.path)
        XCTAssertEqual(detection.checkedPaths.first, "/deleted/brew")
    }
}
