import XCTest
@testable import BrewweryCore

/// The command surface is the security boundary: these assertions pin the exact argument
/// vectors against the legacy `README.md` "Supported Commands" list.
final class HomebrewCommandTests: XCTestCase {

    func testReadCommandArguments() throws {
        XCTAssertEqual(try HomebrewCommand.version.arguments(), ["--version"])
        XCTAssertEqual(try HomebrewCommand.config.arguments(), ["config"])
        XCTAssertEqual(try HomebrewCommand.listFormulae.arguments(), ["list", "--formula", "--json=v2"])
        XCTAssertEqual(try HomebrewCommand.listFormulaeFallback.arguments(), ["list", "--formula", "--versions", "--json"])
        XCTAssertEqual(try HomebrewCommand.listCasks.arguments(), ["list", "--cask", "--json=v2"])
        XCTAssertEqual(try HomebrewCommand.listCasksFallback.arguments(), ["list", "--cask", "--versions", "--json"])
        XCTAssertEqual(try HomebrewCommand.leaves.arguments(), ["leaves"])
        XCTAssertEqual(try HomebrewCommand.outdated.arguments(), ["outdated", "--json=v2"])
        XCTAssertEqual(try HomebrewCommand.listTaps.arguments(), ["tap"])
        XCTAssertEqual(try HomebrewCommand.listServices.arguments(), ["services", "list", "--json"])
        XCTAssertEqual(try HomebrewCommand.cleanupPreview.arguments(), ["cleanup", "-n"])
        XCTAssertEqual(try HomebrewCommand.doctor.arguments(), ["doctor"])
        XCTAssertEqual(try HomebrewCommand.dependents(formula: "redis").arguments(), ["uses", "--installed", "redis"])
        XCTAssertEqual(try HomebrewCommand.searchFormulae(query: "redis").arguments(), ["search", "--formula", "redis"])
        XCTAssertEqual(try HomebrewCommand.searchCasks(query: "redis").arguments(), ["search", "--cask", "redis"])
        XCTAssertEqual(try HomebrewCommand.formulaInfo(name: "redis").arguments(), ["info", "--json=v2", "redis"])
        XCTAssertEqual(try HomebrewCommand.caskInfo(token: "iterm2").arguments(), ["info", "--cask", "--json=v2", "iterm2"])
        XCTAssertEqual(
            try HomebrewCommand.brewfileDump(path: "/tmp/Brewfile").arguments(),
            ["bundle", "dump", "--force", "--file=/tmp/Brewfile"]
        )
    }

    func testMutatingCommandArguments() throws {
        XCTAssertEqual(try HomebrewCommand.update.arguments(), ["update"])
        XCTAssertEqual(try HomebrewCommand.upgradeAll.arguments(), ["upgrade"])
        XCTAssertEqual(try HomebrewCommand.cleanup.arguments(), ["cleanup"])
        XCTAssertEqual(
            try HomebrewCommand.install(.init(name: "redis", kind: .formula)).arguments(),
            ["install", "redis"]
        )
        XCTAssertEqual(
            try HomebrewCommand.install(.init(name: "iterm2", kind: .cask)).arguments(),
            ["install", "--cask", "iterm2"]
        )
        XCTAssertEqual(
            try HomebrewCommand.uninstall(.init(name: "redis", kind: .formula)).arguments(),
            ["uninstall", "redis"]
        )
        XCTAssertEqual(
            try HomebrewCommand.uninstall(.init(name: "iterm2", kind: .cask)).arguments(),
            ["uninstall", "--cask", "iterm2"]
        )
        XCTAssertEqual(
            try HomebrewCommand.upgrade(.init(name: "redis", kind: .formula)).arguments(),
            ["upgrade", "redis"]
        )
        XCTAssertEqual(
            try HomebrewCommand.upgrade(.init(name: "iterm2", kind: .cask)).arguments(),
            ["upgrade", "--cask", "iterm2"]
        )
        XCTAssertEqual(try HomebrewCommand.addTap(name: "user/tools").arguments(), ["tap", "user/tools"])
        XCTAssertEqual(try HomebrewCommand.removeTap(name: "user/tools").arguments(), ["untap", "user/tools"])
        XCTAssertEqual(
            try HomebrewCommand.service(action: .restart, name: "postgresql@17").arguments(),
            ["services", "restart", "postgresql@17"]
        )
    }

    func testCommandsValidateTheirArgumentsBeforeProducingArgv() {
        let hostile = [
            HomebrewCommand.install(.init(name: "redis; rm -rf /", kind: .formula)),
            .uninstall(.init(name: "iterm2 && whoami", kind: .cask)),
            .upgrade(.init(name: "redis|sh", kind: .formula)),
            .service(action: .start, name: "redis service"),
            .addTap(name: "not-a-tap"),
            .removeTap(name: "too/many/parts"),
            .searchFormulae(query: "redis | sh"),
            .formulaInfo(name: "/etc/passwd"),
            .caskInfo(token: "../escape"),
            .dependents(formula: "redis\nwhoami"),
            .brewfileDump(path: "relative/Brewfile")
        ]

        for command in hostile {
            XCTAssertThrowsError(try command.arguments(), command.displayCommand())
        }
    }

    func testUpgradeAllowsLongerIdentifiersThanInstall() {
        let longName = String(repeating: "a", count: 150)
        let reference = PackageReference(name: longName, kind: .formula)

        XCTAssertThrowsError(try HomebrewCommand.install(reference).arguments())
        XCTAssertNoThrow(try HomebrewCommand.upgrade(reference).arguments())
    }

    func testDisplayCommandRendersTheUserVisibleLine() {
        XCTAssertEqual(
            HomebrewCommand.install(.init(name: "iterm2", kind: .cask)).displayCommand(),
            "brew install --cask iterm2"
        )
        XCTAssertEqual(HomebrewCommand.upgradeAll.displayCommand(), "brew upgrade")
        XCTAssertEqual(
            HomebrewCommand.service(action: .stop, name: "redis").displayCommand(),
            "brew services stop redis"
        )
    }

    func testOnlyDoctorToleratesANonZeroExitStatus() {
        XCTAssertTrue(HomebrewCommand.doctor.toleratesNonZeroExit)
        XCTAssertFalse(HomebrewCommand.outdated.toleratesNonZeroExit)
        XCTAssertFalse(HomebrewCommand.cleanup.toleratesNonZeroExit)
    }

    func testOperationTimeoutsMatchTheLegacyPolicy() {
        XCTAssertEqual(OperationKind.install.timeoutSeconds, 45 * 60)
        XCTAssertEqual(OperationKind.uninstall.timeoutSeconds, 15 * 60)
        XCTAssertEqual(OperationKind.upgrade.timeoutSeconds, 45 * 60)
        XCTAssertEqual(OperationKind.service.timeoutSeconds, 5 * 60)
        XCTAssertEqual(OperationKind.cleanup.timeoutSeconds, 30 * 60)
    }

    func testEnvironmentDisablesAutoUpdateAndAnalyticsOnly() {
        let environment = HomebrewEnvironment.values(inheriting: ["PATH": "/usr/bin", "HOMEBREW_NO_INSTALL_CLEANUP": "1"])

        XCTAssertEqual(environment["HOMEBREW_NO_AUTO_UPDATE"], "1")
        XCTAssertEqual(environment["HOMEBREW_NO_ANALYTICS"], "1")
        XCTAssertEqual(environment["PATH"], "/usr/bin")
        // Nothing else is injected: Homebrew behaves as the user configured it.
        XCTAssertEqual(environment["HOMEBREW_NO_INSTALL_CLEANUP"], "1")
        XCTAssertEqual(environment.count, 4)
    }
}
