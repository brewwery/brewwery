import BrewweryCore
import BrewweryTestSupport
import XCTest
@testable import Brewwery

@MainActor
final class ReleaseReliabilityTests: XCTestCase {
    func testFailedPartialInstallRefreshesInstalledPackages() async throws {
        let harness = try AppTestHarness(overrides: """
        if [ "$1" = install ]; then
          /usr/bin/touch "${0%/*}/partially-installed"
          echo "Failed after installing a dependency" >&2
          exit 1
        fi
        if [ "$1" = list ] && [ "$2" = --formula ] && [ -f "${0%/*}/partially-installed" ]; then
          echo '{"formulae":[{"name":"partial-dependency","versions":["1.0"]}],"casks":[]}'
          exit 0
        fi
        """)
        addTeardownBlock { await harness.tearDown() }
        let app = harness.environment
        await app.library.loadAll()
        XCTAssertEqual(app.library.formulae.map(\.name), ["wget"])
        await app.installPackage(.init(name: "hello", kind: .formula))
        XCTAssertEqual(app.history.entries.first?.status, .failed)
        XCTAssertEqual(app.library.formulae.map(\.name), ["partial-dependency"])
    }

    func testCallerCancellationStillRefreshesPartiallyInstalledPackages() async throws {
        let harness = try AppTestHarness(overrides: """
        if [ "$1" = install ]; then
          /usr/bin/touch "${0%/*}/partially-installed"
          /bin/sleep 120 &
          echo $! > "${0%/*}/grandchild.pid"
          wait
          exit 0
        fi
        if [ "$1" = list ] && [ "$2" = --formula ] && [ -f "${0%/*}/partially-installed" ]; then
          echo '{"formulae":[{"name":"partial-dependency","versions":["1.0"]}],"casks":[]}'
          exit 0
        fi
        """)
        addTeardownBlock { await harness.tearDown() }
        let app = harness.environment
        await app.library.loadAll()
        XCTAssertEqual(app.library.formulae.map(\.name), ["wget"])
        let task = Task { await app.installPackage(.init(name: "hello", kind: .formula)) }
        let child = await harness.fake.waitForGrandchildPID()
        XCTAssertNotNil(child)
        task.cancel()
        await task.value
        XCTAssertEqual(app.history.entries.first?.status, .cancelled)
        XCTAssertEqual(app.library.formulae.map(\.name), ["partial-dependency"])
        XCTAssertNil(app.library.formulaeError)
        XCTAssertFalse(app.operations.isRunning)
    }

    func testMetadataAndTapsCannotBypassAnActiveStreamingMutation() async throws {
        let harness = try AppTestHarness()
        addTeardownBlock { await harness.tearDown() }
        let app = harness.environment
        let task = Task { await app.upgradeAllPackages() }
        _ = await harness.fake.waitForGrandchildPID()
        await app.refreshHomebrewMetadata()
        XCTAssertEqual(app.history.entries.first?.error?.code, .operationInProgress)
        await app.performTapAction(.tap, name: "owner/repo")
        XCTAssertEqual(app.history.entries.first?.error?.code, .operationInProgress)
        await app.setPinned(true, formula: "wget")
        XCTAssertFalse(FileManager.default.fileExists(atPath: harness.fake.directory.appendingPathComponent("pinned").path))
        await app.operations.cancel()
        await task.value
    }

    func testDependentsFailureIsNotAnEmptySuccess() async throws {
        let fake = try FakeBrew(overrides: "if [ \"$1\" = uses ]; then echo offline >&2; exit 1; fi")
        defer { fake.cleanUp() }
        let info = PackageInfoModel(client: fake.makeClient())
        info.loadDependents(for: .init(name: "redis", kind: .formula))
        let deadline = Date().addingTimeInterval(5)
        while info.isLoadingDependents, Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertFalse(info.isLoadingDependents)
        XCTAssertNotNil(info.dependentsError)
        XCTAssertTrue(info.dependents.isEmpty)
        info.clear()
        XCTAssertNil(info.dependentsError)
    }

    func testStaleInfoCannotOverwriteNewSelectionOrReopenClosedDrawer() async throws {
        let fake = try FakeBrew(overrides: """
        if [ "$1" = info ]; then
          case "$*" in
            *slow*) /bin/sleep 0.4; name=slow ;;
            *) name=fast ;;
          esac
          echo "{\\"formulae\\":[{\\"name\\":\\"$name\\",\\"versions\\":{\\"stable\\":\\"1.0\\"},\\"installed\\":[]}],\\"casks\\":[]}"
          exit 0
        fi
        """)
        defer { fake.cleanUp() }
        let info = PackageInfoModel(client: fake.makeClient())
        let first = Task { await info.load(.init(name: "slow", kind: .formula)) }
        while !info.isLoading { await Task.yield() }
        await info.load(.init(name: "fast", kind: .formula))
        await first.value
        XCTAssertEqual(info.info?.name, "fast")
        let next = Task { await info.load(.init(name: "slow", kind: .formula)) }
        while !info.isLoading { await Task.yield() }
        info.clear()
        await next.value
        XCTAssertNil(info.info)
        XCTAssertFalse(info.isLoading)
    }

    func testAuthorCreditUsesAnExplicitAllowedProfile() {
        XCTAssertEqual(AppInfo.authorCredit, "by Made Büro")
        XCTAssertEqual(AppInfo.authorURL, "https://github.com/madeburo")
        XCTAssertTrue(ExternalLinkPolicy.isAllowed(AppInfo.authorURL))
        XCTAssertFalse(ExternalLinkPolicy.isAllowed("https://github.com/madeburo-other"))
    }
}
