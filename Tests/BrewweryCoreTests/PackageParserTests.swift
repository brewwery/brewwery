import XCTest
@testable import BrewweryCore

/// Parity tests for `packages.rs`. The first four cases are the legacy Rust unit tests
/// carried over verbatim, so a behavioural drift between the two implementations fails here.
final class PackageParserTests: XCTestCase {

    func testParsesAndNormalizesFormulae() throws {
        let json = """
        {
          "formulae": [{
            "name": "redis",
            "full_name": "redis",
            "desc": "Persistent key-value database",
            "homepage": "https://redis.io/",
            "dependencies": ["openssl@3"],
            "installed": [{"version": "8.0.0", "installed_on_request": true}]
          }]
        }
        """

        let formulae = try PackageParser.parseFormulae(json: json)

        XCTAssertEqual(formulae.count, 1)
        XCTAssertEqual(formulae[0].name, "redis")
        XCTAssertEqual(formulae[0].installedVersion, "8.0.0")
        XCTAssertEqual(formulae[0].installedOnRequest, true)
        XCTAssertEqual(formulae[0].dependencies?.first, "openssl@3")
    }

    func testParsesCaskNameAndInstalledVersion() throws {
        let json = """
        {
          "casks": [{
            "token": "visual-studio-code",
            "name": ["Visual Studio Code"],
            "desc": "Code editor",
            "installed": ["1.100.0"]
          }]
        }
        """

        let casks = try PackageParser.parseCasks(json: json)

        XCTAssertEqual(casks.count, 1)
        XCTAssertEqual(casks[0].token, "visual-studio-code")
        XCTAssertEqual(casks[0].name, ["Visual Studio Code"])
        XCTAssertEqual(casks[0].installedVersion, "1.100.0")
    }

    func testSearchParserIgnoresHomebrewHeaders() {
        let results = PackageParser.parseSearchLines("==> Formulae\nredis redis@6.2\n", kind: .formula)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "redis")
        XCTAssertEqual(results[1].name, "redis@6.2")
        XCTAssertTrue(results.allSatisfy { $0.kind == .formula })
    }

    func testParsesLeavesAndDependentsOutput() {
        XCTAssertEqual(
            PackageParser.parseNameLines("redis\npostgresql@17\n"),
            ["redis", "postgresql@17"]
        )
    }

    // MARK: - Edge cases the Rust types imply but never asserted

    func testCaskAcceptsScalarNameAndInstalledValues() throws {
        let json = """
        {"casks": [{"token": "iterm2", "name": "iTerm2", "installed": "3.5.0"}]}
        """

        let casks = try PackageParser.parseCasks(json: json)

        XCTAssertEqual(casks[0].name, ["iTerm2"])
        XCTAssertEqual(casks[0].installedVersion, "3.5.0")
    }

    func testCaskFallsBackToVersionWhenNotInstalled() throws {
        let json = #"{"casks": [{"token": "figma", "version": "124.5.0"}]}"#

        XCTAssertEqual(try PackageParser.parseCasks(json: json)[0].installedVersion, "124.5.0")
    }

    /// The `--versions --json` fallback Homebrew 5 forces has a flat `versions` array
    /// instead of an `installed` array.
    func testFormulaFallbackShapeSuppliesInstalledVersion() throws {
        let json = #"{"formulae": [{"name": "wget", "versions": ["1.25.0"]}]}"#

        XCTAssertEqual(try PackageParser.parseFormulae(json: json)[0].installedVersion, "1.25.0")
    }

    func testFormulaNameFallsBackToFullNameThenUnknown() throws {
        let json = """
        {"formulae": [{"full_name": "mongodb/brew/mongodb-community"}, {"desc": "orphan"}]}
        """

        let formulae = try PackageParser.parseFormulae(json: json)

        XCTAssertEqual(formulae[0].name, "mongodb/brew/mongodb-community")
        XCTAssertEqual(formulae[1].name, "unknown")
    }

    func testEmptyDependenciesBecomeNil() throws {
        let json = #"{"formulae": [{"name": "jq", "dependencies": []}]}"#

        XCTAssertNil(try PackageParser.parseFormulae(json: json)[0].dependencies)
    }

    func testMissingPayloadKeyYieldsEmptyList() throws {
        XCTAssertTrue(try PackageParser.parseFormulae(json: "{}").isEmpty)
        XCTAssertTrue(try PackageParser.parseCasks(json: "{}").isEmpty)
    }

    func testMalformedJSONReportsParseFailure() {
        XCTAssertThrowsError(try PackageParser.parseFormulae(json: "not json")) { error in
            XCTAssertEqual((error as? BrewweryError)?.code, .brewJSONParseFailed)
        }
    }

    // MARK: - `brew info`

    func testParsesFormulaInfo() throws {
        let json = """
        {
          "formulae": [{
            "name": "redis",
            "full_name": "redis",
            "desc": "Persistent key-value database",
            "homepage": "https://redis.io/",
            "caveats": "To start redis now...",
            "versions": {"stable": "8.0.0"},
            "dependencies": ["openssl@3"],
            "installed": [{"version": "7.2.0", "installed_on_request": true}]
          }]
        }
        """

        let info = try PackageParser.parseFormulaInfo(json: json)

        XCTAssertEqual(info.kind, .formula)
        XCTAssertEqual(info.latestVersion, "8.0.0")
        XCTAssertEqual(info.installedVersion, "7.2.0")
        XCTAssertTrue(info.installed)
        XCTAssertEqual(info.caveats, "To start redis now...")
        XCTAssertEqual(info.rawJSON, json)
        XCTAssertNil(info.token)
    }

    func testFormulaInfoIsNotInstalledWithoutAnInstalledEntry() throws {
        let json = #"{"formulae": [{"name": "ripgrep", "versions": {"stable": "14.1.1"}}]}"#

        let info = try PackageParser.parseFormulaInfo(json: json)

        XCTAssertFalse(info.installed)
        XCTAssertNil(info.installedVersion)
    }

    func testParsesCaskInfoIncludingDependsOn() throws {
        let json = """
        {
          "casks": [{
            "token": "docker",
            "full_token": "homebrew/cask/docker",
            "name": ["Docker Desktop", "Docker"],
            "desc": "Container runtime",
            "version": "4.38.0",
            "installed": "4.37.0",
            "depends_on": {"macos": ">= 12", "cask": ["virtualbox"]}
          }]
        }
        """

        let info = try PackageParser.parseCaskInfo(json: json)

        XCTAssertEqual(info.kind, .cask)
        XCTAssertEqual(info.token, "docker")
        XCTAssertEqual(info.name, "docker")
        XCTAssertEqual(info.fullName, "homebrew/cask/docker")
        XCTAssertEqual(info.displayName, ["Docker Desktop", "Docker"])
        XCTAssertEqual(info.latestVersion, "4.38.0")
        XCTAssertEqual(info.installedVersion, "4.37.0")
        XCTAssertTrue(info.installed)
        // `depends_on` is flattened over its values; ordering is stabilised by key.
        XCTAssertEqual(info.dependencies, ["virtualbox", ">= 12"])
    }

    func testCaskInfoWithoutDependenciesReportsNil() throws {
        let json = #"{"casks": [{"token": "rectangle"}]}"#

        XCTAssertNil(try PackageParser.parseCaskInfo(json: json).dependencies)
    }

    func testMissingInfoEntryReportsPackageInfoFailure() {
        XCTAssertThrowsError(try PackageParser.parseFormulaInfo(json: #"{"formulae": []}"#)) { error in
            XCTAssertEqual((error as? BrewweryError)?.code, .packageInfoFailed)
        }
    }
}
