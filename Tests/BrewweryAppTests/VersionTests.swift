import XCTest
@testable import Brewwery

/// The version appears in three places that can drift apart: the bundle's Info.plist, the
/// fallback used when the app runs unbundled, and the CHANGELOG. This keeps them together.
final class VersionTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // BrewweryAppTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repository root
    }

    func testFallbackVersionMatchesTheBundleVersion() throws {
        let plist = repositoryRoot.appendingPathComponent("Packaging/Info.plist")
        let contents = try Data(contentsOf: plist)
        let info = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: contents, format: nil) as? [String: Any]
        )

        XCTAssertEqual(
            info["CFBundleShortVersionString"] as? String,
            AppInfo.fallbackVersion,
            "bump AppInfo.fallbackVersion with Packaging/Info.plist"
        )
        XCTAssertEqual(info["CFBundleVersion"] as? String, AppInfo.compiledBuild)
    }

    func testChangelogLeadsWithTheCurrentVersion() throws {
        let changelog = try String(contentsOf: repositoryRoot.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
        let firstRelease = changelog
            .split(separator: "\n")
            // Work in progress collects under "## Unreleased" until the version is bumped.
            .first { $0.hasPrefix("## ") && $0 != "## Unreleased" }

        XCTAssertEqual(firstRelease, "## \(AppInfo.fallbackVersion)", "the changelog must open with this release")
    }
}
