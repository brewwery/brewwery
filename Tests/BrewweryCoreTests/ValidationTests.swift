import XCTest
@testable import BrewweryCore

/// Parity tests for the argument validation in `packages.rs`, `updates.rs`, `services.rs`
/// and `taps.rs`. These are the rules that keep shell metacharacters out of `Process`.
final class ValidationTests: XCTestCase {

    private func accepts(_ body: () throws -> Void) -> Bool {
        (try? body()) != nil
    }

    func testValidatesFormulaeCasksAndSearchQueries() {
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateFormulaName("mongodb/brew/mongodb-community") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName("redis;rm") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName("tap//formula") })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateCaskToken("visual-studio-code") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateCaskToken("tap/cask") })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateSearchQuery("postgresql@17") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateSearchQuery("редис") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateSearchQuery("redis | sh") })
    }

    func testValidatesUpgradeTargets() {
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateFormulaName("mongodb/brew/mongodb-community", maxLength: 160) })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName("redis && whoami", maxLength: 160) })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateCaskToken("visual-studio-code", maxLength: 160) })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateCaskToken("homebrew/cask", maxLength: 160) })
    }

    func testValidatesServiceNames() {
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateServiceName("postgresql@17") })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateServiceName("mongodb-community") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateServiceName("redis;rm") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateServiceName("redis service") })
    }

    func testValidatesTapNames() {
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateTapName("homebrew/core") })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateTapName("user/tools-extra") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateTapName("user/tools;whoami") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateTapName("missing-repository") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateTapName("too/many/parts") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateTapName("/leading") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateTapName("trailing/") })
    }

    func testRejectsEmptyAndOverlongIdentifiers() {
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName("") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName(String(repeating: "a", count: 121)) })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateFormulaName(String(repeating: "a", count: 120)) })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateFormulaName(String(repeating: "a", count: 160), maxLength: 160) })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateSearchQuery(String(repeating: "a", count: 81)) })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateSearchQuery("   ") })
    }

    /// A deliberate tightening over 0.9.7, which accepted `..` because `.` and `/` are both
    /// legal identifier characters. See `docs/ARCHITECTURE-DECISIONS.md`.
    func testRejectsPathTraversalSegmentsInFormulaNames() {
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName("../../etc/passwd") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName("tap/../escape") })
        // Names that merely contain dots stay valid.
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateFormulaName("python@3.13") })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateFormulaName("mongodb/brew/mongodb-community") })
    }

    func testRejectsShellMetacharactersAndNewlines() {
        for hostile in ["redis\nwhoami", "redis`id`", "redis$(id)", "redis>out", "redis&", "../../etc/passwd"] {
            XCTAssertFalse(accepts { try HomebrewIdentifier.validateFormulaName(hostile) }, hostile)
            XCTAssertFalse(accepts { try HomebrewIdentifier.validateCaskToken(hostile) }, hostile)
            XCTAssertFalse(accepts { try HomebrewIdentifier.validateServiceName(hostile) }, hostile)
        }
    }

    func testErrorCodesMatchTheLegacyContract() {
        do {
            try HomebrewIdentifier.validateCaskToken("bad/token")
            XCTFail("expected a validation failure")
        } catch {
            XCTAssertEqual(error.code, .invalidCaskToken)
        }

        do {
            try HomebrewIdentifier.validateFormulaName("bad token")
            XCTFail("expected a validation failure")
        } catch {
            XCTAssertEqual(error.code, .invalidPackageName)
        }
    }

    func testSearchQueryConvenienceMatchesTheThrowingRule() {
        XCTAssertTrue(HomebrewIdentifier.isValidSearchQuery("node"))
        XCTAssertFalse(HomebrewIdentifier.isValidSearchQuery(""))
        XCTAssertFalse(HomebrewIdentifier.isValidSearchQuery("visual studio"))
    }

    // MARK: - Brewfile paths

    func testBrewfilePathValidation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let brewfile = directory.appendingPathComponent("Brewfile")
        let suffixed = directory.appendingPathComponent("team.brewfile")
        let other = directory.appendingPathComponent("notes.txt")
        for url in [brewfile, suffixed, other] {
            try "brew \"git\"\n".write(to: url, atomically: true, encoding: .utf8)
        }

        XCTAssertTrue(accepts { try HomebrewIdentifier.validateBrewfilePath(brewfile.path) })
        XCTAssertTrue(accepts { try HomebrewIdentifier.validateBrewfilePath(suffixed.path) })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateBrewfilePath(other.path) })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateBrewfilePath(directory.path) })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateBrewfilePath("Brewfile") })
        XCTAssertFalse(accepts { try HomebrewIdentifier.validateBrewfilePath("/does/not/exist/Brewfile") })
    }
}
