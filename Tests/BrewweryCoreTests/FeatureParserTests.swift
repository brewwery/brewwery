import XCTest
@testable import BrewweryCore

/// Parity tests for `updates.rs`, `services.rs`, `taps.rs`, `cleanup.rs`, `doctor.rs`,
/// `brewfile.rs` and `parser.rs`.
final class FeatureParserTests: XCTestCase {

    // MARK: - Outdated

    func testParsesFormulaAndCaskUpdates() throws {
        let json = """
        {
          "formulae": [{
            "name": "redis",
            "installed_versions": ["7.2.0"],
            "current_version": "8.0.0",
            "pinned": false
          }],
          "casks": [{
            "name": "iterm2",
            "installed_versions": ["3.5.0"],
            "current_version": "3.6.0"
          }]
        }
        """

        let updates = try OutdatedParser.parse(json: json)

        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(updates[0].kind, .formula)
        XCTAssertEqual(updates[0].currentVersion, "7.2.0")
        XCTAssertEqual(updates[0].latestVersion, "8.0.0")
        XCTAssertEqual(updates[0].pinned, false)
        XCTAssertEqual(updates[1].kind, .cask)
    }

    func testOutdatedToleratesMissingVersionArrays() throws {
        let updates = try OutdatedParser.parse(json: #"{"formulae": [{"name": "wget"}]}"#)

        XCTAssertEqual(updates[0].installedVersions, [])
        XCTAssertNil(updates[0].currentVersion)
        XCTAssertNil(updates[0].latestVersion)
    }

    func testOutdatedReportsPinnedVersion() throws {
        let json = """
        {"formulae": [{"name": "node", "installed_versions": ["22.0.0"], "pinned": true, "pinned_version": "22.0.0"}]}
        """

        let update = try OutdatedParser.parse(json: json)[0]

        XCTAssertEqual(update.pinned, true)
        XCTAssertEqual(update.pinnedVersion, "22.0.0")
    }

    // MARK: - Services

    func testNormalizesServiceStatuses() {
        XCTAssertEqual(ServiceParser.normalizeStatus("started"), .started)
        XCTAssertEqual(ServiceParser.normalizeStatus("none"), .stopped)
        XCTAssertEqual(ServiceParser.normalizeStatus("stopped"), .stopped)
        XCTAssertEqual(ServiceParser.normalizeStatus("error"), .error)
        XCTAssertEqual(ServiceParser.normalizeStatus("scheduled"), .unknown)
        XCTAssertEqual(ServiceParser.normalizeStatus(nil), .unknown)
        XCTAssertEqual(ServiceParser.normalizeStatus("STARTED"), .started)
    }

    func testParsesServicesJSON() throws {
        let json = #"[{"name":"redis","status":"started","user":"umid","file":"/tmp/redis.plist"}]"#

        let services = try ServiceParser.parse(json: json)

        XCTAssertEqual(services.count, 1)
        XCTAssertEqual(services[0].name, "redis")
        XCTAssertEqual(services[0].status, .started)
        XCTAssertEqual(services[0].user, "umid")
        XCTAssertNil(services[0].command)
    }

    // MARK: - Taps

    func testParsesTapsAndMarksOfficialEntries() {
        let taps = TapParser.parse("homebrew/core\nuser/tools\n")

        XCTAssertEqual(taps.count, 2)
        XCTAssertTrue(taps[0].official)
        XCTAssertFalse(taps[1].official)
    }

    func testTapParserSkipsBlankLines() {
        XCTAssertEqual(TapParser.parse("\n  homebrew/cask  \n\n").map(\.name), ["homebrew/cask"])
    }

    // MARK: - Cleanup

    func testParsesCleanupItemsAndTotal() {
        let output = """
        Would remove: /opt/homebrew/Cellar/redis/7.2.0 (12 files, 3.4MB)
        This operation would free approximately 3.4MB of disk space.

        """

        let preview = CleanupParser.parsePreview(output)

        XCTAssertEqual(preview.items.count, 1)
        XCTAssertEqual(preview.items[0].name, "7.2.0")
        XCTAssertEqual(preview.items[0].kind, .oldVersion)
        XCTAssertEqual(preview.items[0].size, "3.4MB")
        XCTAssertEqual(preview.totalSize, "3.4MB")
    }

    func testClassifiesCachePaths() {
        XCTAssertEqual(CleanupParser.classify("/Users/test/Library/Caches/Homebrew/file"), .cache)
        XCTAssertEqual(CleanupParser.classify("/opt/homebrew/Cellar/redis/1"), .oldVersion)
        XCTAssertEqual(CleanupParser.classify("/Users/test/Library/Logs/Homebrew/wget"), .download)
        XCTAssertEqual(CleanupParser.classify("/tmp/file"), .unknown)
    }

    func testParsesBrokenLinkCleanupLines() {
        let item = CleanupParser.parseItem("Would remove (broken link): /opt/homebrew/lib/libfoo.dylib")

        XCTAssertEqual(item?.path, "/opt/homebrew/lib/libfoo.dylib")
        XCTAssertEqual(item?.name, "libfoo.dylib")
        XCTAssertNil(item?.size)
    }

    func testSplitsSizeWithoutFileCount() {
        let (path, size) = CleanupParser.splitPathAndSize("/opt/homebrew/Cellar/jq/1.7 (12.4KB)")

        XCTAssertEqual(path, "/opt/homebrew/Cellar/jq/1.7")
        XCTAssertEqual(size, "12.4KB")
    }

    func testIgnoresUnrelatedCleanupLines() {
        XCTAssertNil(CleanupParser.parseItem("==> Cleaning up"))
        XCTAssertTrue(CleanupParser.parsePreview("Nothing to do.\n").items.isEmpty)
    }

    func testCountsRemovalsAndReadsFreedSpaceFromACompletedRun() {
        let output = """
        Removing: /Users/test/Library/Caches/Homebrew/wget--1.25.0.tar.gz... (1.4MB)
        Removing: /opt/homebrew/Cellar/redis/7.2.0... (12 files, 3.4MB)
        Pruned 2 symbolic links from /opt/homebrew
        ==> This operation has freed approximately 4.8MB of disk space.
        """

        XCTAssertEqual(CleanupParser.countRemovals(output), 3)
        XCTAssertEqual(CleanupParser.findFreedSpace(output), "4.8MB")
    }

    // MARK: - Doctor

    func testParsesMultipleDoctorWarnings() {
        let output = """
        Warning: Unbrewed dylibs were found
        Remove the files.

        Warning: Broken symlinks were found
        Run brew cleanup.

        """

        let diagnostics = DoctorParser.parse(output)

        XCTAssertEqual(diagnostics.count, 2)
        XCTAssertEqual(diagnostics[0].severity, .warning)
        XCTAssertEqual(diagnostics[0].title, "Unbrewed dylibs were found")
        XCTAssertEqual(diagnostics[0].message, "Remove the files.")
        XCTAssertEqual(diagnostics[1].message, "Run brew cleanup.")
        XCTAssertEqual(diagnostics[1].raw, "Warning: Broken symlinks were found\nRun brew cleanup.")
    }

    func testHealthyOutputHasNoDiagnostics() {
        XCTAssertTrue(DoctorParser.parse("Your system is ready to brew.").isEmpty)
    }

    func testHealthyResultRequiresBothNoDiagnosticsAndTheReadyLine() {
        XCTAssertTrue(DoctorParser.makeResult(rawOutput: "Your system is ready to brew.").healthy)
        // Silence is not health: without the marker line Brewwery does not claim success.
        XCTAssertFalse(DoctorParser.makeResult(rawOutput: "").healthy)
        XCTAssertFalse(
            DoctorParser.makeResult(rawOutput: "Warning: Broken symlinks were found\nRun brew cleanup.").healthy
        )
    }

    func testTitleOnlyWarningKeepsTitleAsRaw() {
        let diagnostics = DoctorParser.parse("Warning: Homebrew's sbin was not found in your PATH\n")

        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics[0].message, "")
        XCTAssertEqual(diagnostics[0].raw, "Homebrew's sbin was not found in your PATH")
    }

    // MARK: - Brewfile

    func testParsesBrewfileEntries() {
        let content = """
        # comment
        tap "homebrew/services"
        brew "git"
        cask "visual-studio-code"
        mas "Xcode", id: 497799835
        vscode "golang.go"

        """

        let entries = BrewfileParser.parse(content)

        XCTAssertEqual(entries.map(\.kind), [.tap, .brew, .cask, .mas, .unknown])
        XCTAssertEqual(entries.map(\.name), ["homebrew/services", "git", "visual-studio-code", "Xcode", "golang.go"])
        XCTAssertEqual(entries[1].raw, #"brew "git""#)
    }

    func testBrewfileLineWithoutQuotesKeepsTheWholeLineAsName() {
        let entries = BrewfileParser.parse("brew git\n")

        XCTAssertEqual(entries[0].kind, .brew)
        XCTAssertEqual(entries[0].name, "brew git")
    }

    func testBrewfileSkipsCommentsAndBlankLines() {
        XCTAssertTrue(BrewfileParser.parse("\n\n   \n# only comments\n").isEmpty)
    }

    // MARK: - brew config

    func testParsesKeyValueLines() {
        let pairs = KeyValueParser.parse("HOMEBREW_VERSION: 4.5.0\nHOMEBREW_PREFIX: /opt/homebrew\nnot a pair\n")

        XCTAssertEqual(pairs.count, 2)
        XCTAssertEqual(KeyValueParser.value(for: "HOMEBREW_PREFIX", in: pairs), "/opt/homebrew")
        XCTAssertNil(KeyValueParser.value(for: "MISSING", in: pairs))
    }

    func testBuildsBrewInfoFromConfig() {
        let config = """
        HOMEBREW_VERSION: 4.5.0
        HOMEBREW_PREFIX: /opt/homebrew
        macOS: 15.3-arm64
        """

        let info = BrewConfigParser.makeInfo(path: "/opt/homebrew/bin/brew", configOutput: config, versionOutput: nil)

        XCTAssertEqual(info.version, "4.5.0")
        XCTAssertEqual(info.prefix, "/opt/homebrew")
        XCTAssertEqual(info.architecture, .arm64)
        XCTAssertEqual(info.path, "/opt/homebrew/bin/brew")
    }

    func testBrewInfoFallsBackToVersionOutputAndReportsUnknowns() {
        let info = BrewConfigParser.makeInfo(
            path: "/usr/local/bin/brew",
            configOutput: nil,
            versionOutput: "Homebrew 4.5.0\nHomebrew/homebrew-core (git revision abc)"
        )

        XCTAssertEqual(info.version, "Homebrew 4.5.0")
        XCTAssertEqual(info.prefix, "unknown")
    }

    func testIntelConfigReportsX86() {
        let info = BrewConfigParser.makeInfo(
            path: "/usr/local/bin/brew",
            configOutput: "macOS: 14.7-x86_64",
            versionOutput: nil
        )

        XCTAssertEqual(info.architecture, .x86_64)
    }
}
