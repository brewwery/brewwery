import XCTest
@testable import BrewweryCore
import BrewweryTestSupport

/// Tests the client's orchestration and its error mapping, which the UI keys its recovery
/// panels off.
final class HomebrewClientTests: XCTestCase {
    private var fake: FakeBrew!
    private var client: HomebrewClient!

    override func setUpWithError() throws {
        fake = try FakeBrew()
        client = fake.makeClient()
    }

    override func tearDown() {
        fake.cleanUp()
    }

    func testListsInstalledFormulaeThroughTheArgumentFallback() async throws {
        let formulae = try await client.installedFormulae()

        XCTAssertEqual(formulae.map(\.name), ["wget"])
    }

    func testReadsLeaves() async throws {
        let leaves = try await client.leaves()

        XCTAssertEqual(leaves, ["redis", "postgresql@17"])
    }

    func testBuildsBrewInfoFromConfig() async throws {
        let info = try await client.brewInfo()

        XCTAssertEqual(info.version, "4.5.0-test")
        XCTAssertEqual(info.prefix, "/opt/homebrew")
        XCTAssertEqual(info.architecture, .arm64)
        XCTAssertEqual(info.path, fake.executable.path)
    }

    func testDoctorParsesDiagnosticsInsteadOfDumpingRawOutput() async throws {
        let result = try await client.doctor()

        XCTAssertFalse(result.healthy)
        XCTAssertEqual(result.diagnostics.count, 1)
        XCTAssertEqual(result.diagnostics[0].title, "Broken symlinks were found")
        XCTAssertNotNil(result.rawOutput)
    }

    func testOutdatedFailureKeepsTheCommandFailureCode() async {
        do {
            _ = try await client.outdated()
            XCTFail("expected the command to fail")
        } catch {
            XCTAssertEqual(error.code, .brewCommandFailed)
        }
    }

    func testSearchValidationErrorIsNotRewrittenAsASearchFailure() async {
        do {
            _ = try await client.search("redis | sh")
            XCTFail("expected validation to reject the query")
        } catch {
            XCTAssertEqual(error.code, .invalidPackageName)
        }
    }

    func testMissingHomebrewFailsEveryFeatureTheSameWay() async throws {
        let missing = HomebrewClient(
            detector: HomebrewDetector(candidatePaths: ["/nonexistent/brew"], environment: ["PATH": "/nonexistent"])
        )

        do {
            _ = try await missing.installedCasks()
            XCTFail("expected HOMEBREW_NOT_FOUND")
        } catch {
            XCTAssertEqual(error.code, .homebrewNotFound)
            XCTAssertEqual(
                error.friendlyMessage,
                "Brewwery could not find Homebrew. Install Homebrew or set a custom path in Settings."
            )
        }
    }

    /// Every read and every mutation fails with the same code, so every page can render the
    /// same recovery panel.
    func testEveryFeatureReportsHomebrewNotFound() async {
        let missing = HomebrewClient(
            detector: HomebrewDetector(candidatePaths: ["/nonexistent/brew"], environment: ["PATH": "/nonexistent"])
        )
        let calls: [(String, () async throws -> Void)] = [
            ("formulae", { _ = try await missing.installedFormulae() }),
            ("outdated", { _ = try await missing.outdated() }),
            ("services", { _ = try await missing.services() }),
            ("taps", { _ = try await missing.taps() }),
            ("search", { _ = try await missing.search("redis") }),
            ("cleanup", { _ = try await missing.cleanupPreview() }),
            ("doctor", { _ = try await missing.doctor() }),
            ("brewfile", { _ = try await missing.exportBrewfile() }),
            ("update", { try await missing.updateMetadata() }),
            ("stream", { _ = try await missing.stream(.cleanup, kind: .cleanup, id: UUID()) })
        ]

        for (name, call) in calls {
            do {
                try await call()
                XCTFail("\(name) should have failed")
            } catch {
                XCTAssertEqual((error as? BrewweryError)?.code, .homebrewNotFound, name)
            }
        }
    }

    func testReadsAndValidatesABrewfile() async throws {
        let path = fake.directory.appendingPathComponent("Brewfile")
        try """
        tap "homebrew/services"
        brew "git"
        cask "iterm2"
        """.write(to: path, atomically: true, encoding: .utf8)

        let document = try await client.readBrewfile(at: path.path)

        XCTAssertEqual(document.entries.count, 3)
        XCTAssertEqual(document.entries.map(\.kind), [.tap, .brew, .cask])
        XCTAssertEqual(document.path, path.path)
    }

    func testRejectsABrewfilePathThatIsNotABrewfile() async {
        do {
            _ = try await client.readBrewfile(at: "/etc/hosts")
            XCTFail("expected the path to be rejected")
        } catch {
            XCTAssertEqual(error.code, .invalidFilePath)
        }
    }
}
