import AppKit
import BrewweryCore
import BrewweryTestSupport
import SwiftUI
import XCTest
@testable import Brewwery

/// An app environment wired to the `brew` test double, a throwaway defaults suite and a
/// temporary directory — nothing a test does reaches the real Homebrew, the user's settings
/// or `~/Library/Application Support/Brewwery`.
@MainActor
struct AppTestHarness {
    let fake: FakeBrew
    let environment: AppEnvironment
    let directory: URL
    let suiteName: String

    init() throws {
        _ = NSApplication.shared
        fake = try FakeBrew()
        directory = fake.directory.appendingPathComponent("state", isDirectory: true)
        suiteName = "brewwery-app-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))

        let settings = SettingsStore(defaults: defaults)
        // Stored like a user-chosen path, so `AppEnvironment.prepare()` re-applies the double
        // instead of clearing it.
        settings.customHomebrewPath = fake.executable.path

        environment = AppEnvironment(
            client: fake.makeClient(),
            settings: settings,
            history: HistoryStore(directory: directory),
            favorites: FavoritesStore(directory: directory)
        )
    }

    /// Guards against the failure this harness exists to prevent: a test reaching the real
    /// Homebrew installation.
    func assertUsingDouble(file: StaticString = #filePath, line: UInt = #line) async {
        let detection = await environment.client.detect()
        XCTAssertEqual(detection.path, fake.executable.path, "tests must never reach the real Homebrew", file: file, line: line)
    }

    func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        fake.cleanUp()
    }

    // MARK: - Rendering

    /// Hosts a view in an off-screen window and waits for its asynchronous loads to settle.
    func host(
        _ view: some View,
        size: CGSize = Metrics.defaultWindowSize,
        appearance: NSAppearance.Name = .darkAqua,
        settle: Duration = .milliseconds(1_500)
    ) async throws -> NSWindow {
        let hosting = NSHostingView(rootView: view.background(BrewweryColor.appPanel).environment(environment))
        hosting.frame = CGRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentView = hosting
        window.layoutIfNeeded()

        try await Task.sleep(for: settle)
        hosting.layoutSubtreeIfNeeded()
        return window
    }

    /// Renders the window's content to PNG. With `BREWWERY_SNAPSHOT_DIR` set the image is also
    /// written there, so a person can review every screen after a UI change.
    @discardableResult
    func snapshot(_ window: NSWindow, named name: String) throws -> NSBitmapImageRep {
        let view = try XCTUnwrap(window.contentView)
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)

        if let directory = ProcessInfo.processInfo.environment["BREWWERY_SNAPSHOT_DIR"] {
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        }
        return bitmap
    }
}

extension NSBitmapImageRep {
    /// Whether the render contains more than a flat fill — a blank capture means the view
    /// failed to draw.
    var hasVisibleContent: Bool {
        guard pixelsWide > 0, pixelsHigh > 0 else { return false }
        var colours = Set<UInt32>()
        let stepX = max(pixelsWide / 40, 1)
        let stepY = max(pixelsHigh / 40, 1)
        for x in stride(from: 0, to: pixelsWide, by: stepX) {
            for y in stride(from: 0, to: pixelsHigh, by: stepY) {
                guard let colour = colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let key = UInt32(colour.redComponent * 255) << 16
                    | UInt32(colour.greenComponent * 255) << 8
                    | UInt32(colour.blueComponent * 255)
                colours.insert(key)
                if colours.count > 6 { return true }
            }
        }
        return false
    }
}
