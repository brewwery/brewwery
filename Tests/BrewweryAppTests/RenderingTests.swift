import AppKit
import BrewweryCore
import SwiftUI
import XCTest
@testable import Brewwery

/// Renders every screen and overlay against the `brew` double.
///
/// Each render is checked for real content. With `BREWWERY_SNAPSHOT_DIR` set, the PNGs are
/// kept for review:
///
///     BREWWERY_SNAPSHOT_DIR=/tmp/brewwery-snapshots swift test --filter RenderingTests
@MainActor
final class RenderingTests: XCTestCase {
    private var harness: AppTestHarness!
    private var app: AppEnvironment { harness.environment }

    override func setUp() async throws {
        harness = try AppTestHarness()
        await app.prepare()
        await harness.assertUsingDouble()
    }

    override func tearDown() async throws {
        harness?.tearDown()
    }

    func testEveryPageRendersInBothThemes() async throws {
        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            let theme = appearance == .darkAqua ? "dark" : "light"
            for page in Page.allCases {
                app.state.select(page)
                let window = try await harness.host(RootView(), appearance: appearance)
                let image = try harness.snapshot(window, named: "page-\(page.rawValue)-\(theme)")
                XCTAssertTrue(image.hasVisibleContent, "\(page.rawValue) rendered blank in \(theme)")
            }
        }
    }

    func testConfirmationDialogShowsTheExactCommand() async throws {
        let request = ConfirmationRequest.uninstall(.init(name: "iterm2", kind: .cask))
        XCTAssertEqual(request.command, "brew uninstall --cask iterm2")
        XCTAssertEqual(request.confirmLabel, "Uninstall")

        let window = try await harness.host(
            ConfirmationDialogView(request: request, onCancel: {}, onConfirm: {}),
            size: CGSize(width: 720, height: 420),
            settle: .milliseconds(200)
        )
        XCTAssertTrue(try harness.snapshot(window, named: "overlay-confirmation").hasVisibleContent)
    }

    func testPackageDetailDrawerRendersEverySection() async throws {
        let info = PackageInfo(
            name: "redis",
            fullName: "redis",
            kind: .formula,
            description: "Persistent key-value database, with built-in net interface",
            homepage: "https://redis.io/",
            latestVersion: "8.2.1",
            installedVersion: "8.2.0",
            dependencies: ["openssl@3"],
            caveats: "To start redis now and restart at login:\n  brew services start redis",
            installed: true,
            rawJSON: "{\"formulae\":[]}"
        )

        let window = try await harness.host(
            PackageDetailDrawer(
                detail: .info(info),
                dependents: ["hiredis"],
                onClose: {},
                onUninstall: { _ in }
            ),
            size: CGSize(width: 900, height: 1_100),
            settle: .milliseconds(300)
        )
        XCTAssertTrue(try harness.snapshot(window, named: "overlay-drawer").hasVisibleContent)
    }

    func testProgressPanelRendersLiveOutputWhileRunning() async throws {
        let run = Task { await app.upgradePackage(.init(name: "redis", kind: .formula)) }
        _ = await harness.fake.waitForGrandchildPID()

        let window = try await harness.host(
            VStack { OperationProgressPanel() }.padding(24),
            size: CGSize(width: 900, height: 520),
            settle: .milliseconds(400)
        )
        XCTAssertEqual(app.operations.progress?.status, .running)
        XCTAssertTrue(try harness.snapshot(window, named: "overlay-progress-running").hasVisibleContent)

        await app.operations.cancel()
        await run.value
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(try harness.snapshot(window, named: "overlay-progress-cancelled").hasVisibleContent)
    }

    func testHomebrewNotFoundStateRenders() async throws {
        let suite = "brewwery-missing-\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        // Fresh settings: the shared harness settings carry the double's path.
        let missing = AppEnvironment(
            client: HomebrewClient(
                detector: HomebrewDetector(candidatePaths: ["/nonexistent/brew"], environment: ["PATH": "/nonexistent"])
            ),
            settings: SettingsStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))),
            history: app.history,
            favorites: app.favorites
        )
        await missing.prepare()
        XCTAssertTrue(missing.system.isHomebrewMissing)

        let hosting = NSHostingView(rootView: RootView().environment(missing))
        hosting.frame = CGRect(origin: .zero, size: Metrics.defaultWindowSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        try await Task.sleep(for: .milliseconds(1_200))

        XCTAssertTrue(try harness.snapshot(window, named: "state-homebrew-not-found").hasVisibleContent)
    }
}
