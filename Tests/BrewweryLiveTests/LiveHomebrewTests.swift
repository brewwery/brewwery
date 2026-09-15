import XCTest
@testable import BrewweryCore

/// End-to-end checks against the real Homebrew installation.
///
/// These change the Mac they run on, so they are opt-in:
///
///     BREWWERY_LIVE=1 swift test --filter BrewweryLiveTests
///
/// They only touch packages chosen because they have no dependencies and are unlikely to be
/// in use — `hello`, `go` and `etcd` — plus the small `teamookla/speedtest` tap, and each
/// test removes what it added. Upgrading a real outdated formula is a separate opt-in:
/// set `BREWWERY_LIVE_UPGRADE=<formula>`.
@MainActor
final class LiveHomebrewTests: XCTestCase {
    private var client: HomebrewClient!
    private var coordinator: OperationCoordinator!

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BREWWERY_LIVE"] == "1", "set BREWWERY_LIVE=1 to run")
        client = HomebrewClient()
        coordinator = OperationCoordinator(client: client)
        let detection = await client.detect()
        try XCTSkipUnless(detection.found, "no Homebrew on this Mac")
    }

    // MARK: - Reads

    func testEveryReadOnlyQuerySucceeds() async throws {
        let info = try await client.brewInfo()
        XCTAssertNotEqual(info.version, "unknown")
        XCTAssertNotEqual(info.prefix, "unknown")

        let formulae = try await client.installedFormulae()
        XCTAssertFalse(formulae.isEmpty, "expected installed formulae on this Mac")
        _ = try await client.installedCasks()
        _ = try await client.leaves()
        _ = try await client.outdated()
        _ = try await client.services()
        _ = try await client.taps()

        let results = try await client.search("hello")
        XCTAssertTrue(results.contains { $0.name == "hello" && $0.kind == .formula })

        let formulaInfo = try await client.packageInfo(for: .init(name: "hello", kind: .formula))
        XCTAssertEqual(formulaInfo.name, "hello")
        XCTAssertNotNil(formulaInfo.latestVersion)

        let caskInfo = try await client.packageInfo(for: .init(name: "iterm2", kind: .cask))
        XCTAssertEqual(caskInfo.token, "iterm2")
        XCTAssertEqual(caskInfo.displayName?.first, "iTerm2")

        let doctor = try await client.doctor()
        XCTAssertNotNil(doctor.rawOutput)

        let preview = try await client.cleanupPreview()
        XCTAssertNotNil(preview.rawOutput ?? "")

        let brewfile = try await client.exportBrewfile()
        XCTAssertTrue(brewfile.entries.contains { $0.kind == .brew })
    }

    func testCustomPathIsHonouredEndToEnd() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("brewwery-live-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let detected = await client.detect()
        let realBrew = try XCTUnwrap(detected.path)
        let link = directory.appendingPathComponent("brew")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: realBrew)

        let custom = HomebrewClient(detector: HomebrewDetector(customPath: link.path))
        let detection = await custom.detect()
        XCTAssertEqual(detection.path, link.path)
        XCTAssertEqual(detection.checkedPaths.first, link.path)

        let info = try await custom.brewInfo()
        XCTAssertEqual(info.path, link.path)
        XCTAssertNotEqual(info.version, "unknown")
    }

    /// Homebrew cannot reach the network: the failure must surface as the stable metadata
    /// error with its friendly copy, not hang or crash.
    func testUnreachableNetworkIsReportedAsAMetadataFailure() async throws {
        var environment = HomebrewEnvironment.values()
        for key in ["HTTPS_PROXY", "https_proxy", "HTTP_PROXY", "http_proxy", "ALL_PROXY", "all_proxy"] {
            environment[key] = "http://127.0.0.1:9"
        }
        let offline = HomebrewClient(environment: environment)

        let started = Date()
        do {
            try await offline.updateMetadata()
            XCTFail("brew update should fail without a network")
        } catch {
            XCTAssertEqual(error.code, .brewUpdateFailed)
            XCTAssertFalse(error.friendlyMessage.isEmpty)
            XCTAssertNotNil(error.raw, "the underlying Homebrew output should be kept for Show details")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 180, "a network failure should not hang")
    }

    func testMetadataUpdateSucceeds() async throws {
        let output = try await client.updateMetadata()
        XCTAssertTrue(output.success)
    }

    // MARK: - Mutations

    func testInstallAndUninstallAFormula() async throws {
        let hello = PackageReference(name: "hello", kind: .formula)
        try await requireNotInstalled(hello.name)
        addTeardownBlock { await Self.uninstallIfPresent("hello") }

        let installed = try await coordinator.run(.install(hello), kind: .install, target: hello.name)
        guard case .completed = installed else { return XCTFail("install failed: \(String(describing: installed.error))") }
        XCTAssertFalse(coordinator.progress?.lines.isEmpty ?? true, "install should stream output")
        let afterInstall = try await client.installedFormulae()
        XCTAssertTrue(afterInstall.contains { $0.name == "hello" })

        let removed = try await coordinator.run(.uninstall(hello), kind: .uninstall, target: hello.name)
        guard case .completed = removed else { return XCTFail("uninstall failed: \(String(describing: removed.error))") }
        let afterUninstall = try await client.installedFormulae()
        XCTAssertFalse(afterUninstall.contains { $0.name == "hello" })
    }

    /// Cancels a real install while it is still downloading, then checks that nothing was
    /// installed and no Homebrew process was left behind.
    func testCancellingAnInstallLeavesNothingBehind() async throws {
        let go = PackageReference(name: "go", kind: .formula)
        try await requireNotInstalled(go.name)
        addTeardownBlock { await Self.uninstallIfPresent("go") }

        let run = Task { try await coordinator.run(.install(go), kind: .install, target: go.name) }

        // Wait for Homebrew to start talking, then give the download a moment to begin.
        let deadline = Date().addingTimeInterval(60)
        while (coordinator.progress?.lines.isEmpty ?? true), Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(coordinator.progress?.lines.isEmpty ?? true, "install never produced output")
        try await Task.sleep(for: .milliseconds(800))

        await coordinator.cancel()
        let outcome = try await run.value

        XCTAssertEqual(outcome.error?.code, .operationCancelled)
        XCTAssertEqual(coordinator.progress?.status, .cancelled)

        try await Task.sleep(for: .seconds(2))
        XCTAssertFalse(Self.processExists(matching: "brew.rb install go"), "a Homebrew process survived cancellation")
        XCTAssertFalse(Self.processExists(matching: "curl.*go--"), "a download process survived cancellation")
        let formulae = try await client.installedFormulae()
        XCTAssertFalse(formulae.contains { $0.name == "go" }, "the cancelled install left go installed")
    }

    func testServiceStartAndStop() async throws {
        let etcd = PackageReference(name: "etcd", kind: .formula)
        try await requireNotInstalled(etcd.name)
        let dataDirectory = try await client.brewInfo().prefix + "/var/etcd"
        let dataExisted = FileManager.default.fileExists(atPath: dataDirectory)
        addTeardownBlock {
            _ = try? await HomebrewClient().stream(.service(action: .stop, name: "etcd"), kind: .service, id: UUID())
            await Self.uninstallIfPresent("etcd")
            if !dataExisted { try? FileManager.default.removeItem(atPath: dataDirectory) }
        }

        let installed = try await coordinator.run(.install(etcd), kind: .install, target: etcd.name)
        guard case .completed = installed else { return XCTFail("install failed: \(String(describing: installed.error))") }

        let started = try await coordinator.run(.service(action: .start, name: "etcd"), kind: .service, target: "etcd")
        guard case .completed = started else { return XCTFail("start failed: \(String(describing: started.error))") }
        let runningStatus = try await waitForService("etcd") { $0 == .started }
        XCTAssertEqual(runningStatus, .started)

        let stopped = try await coordinator.run(.service(action: .stop, name: "etcd"), kind: .service, target: "etcd")
        guard case .completed = stopped else { return XCTFail("stop failed: \(String(describing: stopped.error))") }
        let stoppedStatus = try await waitForService("etcd") { $0 == .stopped }
        XCTAssertEqual(stoppedStatus, .stopped)

        let removed = try await coordinator.run(.uninstall(etcd), kind: .uninstall, target: etcd.name)
        guard case .completed = removed else { return XCTFail("uninstall failed: \(String(describing: removed.error))") }
    }

    func testAddAndRemoveATap() async throws {
        let tap = "teamookla/speedtest"
        let before = try await client.taps()
        try XCTSkipIf(before.contains { $0.name == tap }, "\(tap) is already tapped on this Mac")
        addTeardownBlock { _ = try? await HomebrewClient().removeTap(tap) }

        try await client.addTap(tap)
        let afterAdd = try await client.taps()
        XCTAssertTrue(afterAdd.contains { $0.name == tap && !$0.official })

        try await client.removeTap(tap)
        let afterRemove = try await client.taps()
        XCTAssertFalse(afterRemove.contains { $0.name == tap })
    }

    func testUpgradeOneOutdatedFormula() async throws {
        guard let name = ProcessInfo.processInfo.environment["BREWWERY_LIVE_UPGRADE"] else {
            throw XCTSkip("set BREWWERY_LIVE_UPGRADE=<formula> to upgrade a real package")
        }
        let before = try await client.outdated()
        try XCTSkipUnless(before.contains { $0.name == name }, "\(name) is not outdated")

        let outcome = try await coordinator.run(.upgrade(.init(name: name, kind: .formula)), kind: .upgrade, target: name)
        guard case .completed = outcome else { return XCTFail("upgrade failed: \(String(describing: outcome.error))") }

        let after = try await client.outdated()
        XCTAssertFalse(after.contains { $0.name == name })
    }

    // MARK: - Helpers

    private func requireNotInstalled(_ name: String) async throws {
        let formulae = try await client.installedFormulae()
        try XCTSkipIf(formulae.contains { $0.name == name }, "\(name) is already installed; not touching it")
    }

    private func waitForService(_ name: String, until done: (ServiceStatus) -> Bool) async throws -> ServiceStatus? {
        var status: ServiceStatus?
        for _ in 0..<20 {
            status = try await client.services().first { $0.name == name }?.status
            if let status, done(status) { return status }
            try await Task.sleep(for: .milliseconds(500))
        }
        return status
    }

    private static func uninstallIfPresent(_ name: String) async {
        let client = HomebrewClient()
        guard (try? await client.installedFormulae())?.contains(where: { $0.name == name }) == true,
              let events = try? await client.stream(.uninstall(.init(name: name, kind: .formula)), kind: .uninstall, id: UUID())
        else { return }
        for await _ in events {}
    }

    private static func processExists(matching pattern: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", pattern]
        process.standardOutput = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
