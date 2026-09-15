import AppKit
import BrewweryCore
import SwiftUI

/// AppKit-level behaviour SwiftUI does not express: the Dock badge, the menu-bar status
/// item, the About panel contents and the ⌃C window-centring gesture.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var statusItem: NSStatusItem?
    private var badgeTask: Task<Void, Never>?
    private var keyMonitor: Any?
    private var aboutPanelOptions: [NSApplication.AboutPanelOptionKey: Any] = [:]

    /// Background outdated check (`update-badge.ts`): first run after 15 s, then every
    /// 30 min. It is read-only — it never refreshes Homebrew metadata or mutates packages.
    static let badgeInitialDelay = Duration.seconds(15)
    static let badgeInterval = Duration.seconds(30 * 60)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = AppAssets.appIcon

        aboutPanelOptions = [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .credits: NSAttributedString(
                string: "\(AppInfo.tagline)\n\(AppInfo.copyright)",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            )
        ]
    }

    /// Called once the SwiftUI scene exists and the environment is available.
    func configure(with environment: AppEnvironment) {
        guard self.environment == nil else { return }
        self.environment = environment

        installStatusItem()
        installWindowCenteringShortcut()
        startBackgroundBadgeRefresh()
        configureMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { NSApp.windows.first?.makeKeyAndOrderFront(nil) }
        return true
    }

    /// Shows the About panel with Brewwery's own name, version and credits.
    @objc func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: aboutPanelOptions)
    }

    func applicationWillTerminate(_ notification: Notification) {
        badgeTask?.cancel()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    // MARK: - Window

    private func configureMainWindow() {
        guard let window = NSApp.windows.first else { return }
        window.title = AppInfo.name
        // `trafficLightPosition: { x: 16, y: 18 }` — the legacy inset.
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor(BrewweryColor.appPanel)
        window.minSize = Metrics.minimumWindowSize
        centerOnActiveScreen(window)
    }

    /// `before-input-event` in `window.ts`: plain ⌃C re-centres and focuses the window.
    private func installWindowCenteringShortcut() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers == .control, event.charactersIgnoringModifiers?.lowercased() == "c" else {
                return event
            }
            self?.presentMainWindow(centered: true)
            return nil
        }
    }

    private func centerOnActiveScreen(_ window: NSWindow) {
        guard let frame = (NSScreen.screens.first { $0.frame.intersects(window.frame) } ?? NSScreen.main)?.visibleFrame
        else { return }
        window.setFrameOrigin(
            NSPoint(
                x: frame.origin.x + (frame.width - window.frame.width) / 2,
                y: frame.origin.y + (frame.height - window.frame.height) / 2
            )
        )
    }

    private func presentMainWindow(centered: Bool = false, page: Page? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = NSApp.windows.first else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        if centered { centerOnActiveScreen(window) }
        window.makeKeyAndOrderFront(nil)
        if let page { environment?.state.select(page) }
    }

    // MARK: - Menu bar status item

    /// `tray.ts` — a template-image status item with the same five entries.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = AppAssets.menuBarIcon
        item.button?.image?.isTemplate = true
        item.button?.toolTip = AppInfo.name

        let menu = NSMenu()
        menu.addItem(menuItem("Open Brewwery", page: nil))
        menu.addItem(menuItem("Check for updates", page: .updates))
        menu.addItem(menuItem("Run doctor", page: .doctor))
        menu.addItem(menuItem("Settings", page: .settings))
        menu.addItem(.separator())
        // A custom selector rather than `terminate:`: macOS attaches a symbol to menu items that
        // use the standard quit action, and the status menu is text-only.
        let quit = NSMenuItem(title: "Quit", action: #selector(quitFromStatusItem), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    private func menuItem(_ title: String, page: Page?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleStatusItem(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = page?.rawValue
        return item
    }

    @objc private func quitFromStatusItem() {
        NSApp.terminate(nil)
    }

    @objc private func handleStatusItem(_ sender: NSMenuItem) {
        presentMainWindow(page: (sender.representedObject as? String).flatMap(Page.init))
    }

    // MARK: - Dock badge

    private func startBackgroundBadgeRefresh() {
        badgeTask = Task { [weak self] in
            try? await Task.sleep(for: Self.badgeInitialDelay)
            while !Task.isCancelled {
                await self?.refreshBadge()
                try? await Task.sleep(for: Self.badgeInterval)
            }
        }
    }

    private func refreshBadge() async {
        guard let environment else { return }
        // Best effort: a background check must never interrupt the app.
        let outdated = (try? await environment.client.outdated()) ?? []
        setBadge(count: outdated.count)
    }

    func setBadge(count: Int) {
        NSApp.dockTile.badgeLabel = count > 0 ? String(count) : nil
    }
}
