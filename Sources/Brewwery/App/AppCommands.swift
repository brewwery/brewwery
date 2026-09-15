import BrewweryCore
import SwiftUI

/// Menu bar commands.
///
/// The shortcut set is exactly the legacy one — ⌘, ⌘K, ⌘R, ⌘W — with no additions during
/// the parity phase. `Settings…` selects the in-app Settings page rather than opening a
/// preferences window, because that is where 0.9.7 put every setting; see
/// `docs/ARCHITECTURE-DECISIONS.md`.
struct AppCommands: Commands {
    let environment: AppEnvironment

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { environment.state.select(.settings) }
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .appInfo) {
            Button("About Brewwery") {
                (NSApp.delegate as? AppDelegate)?.showAboutPanel()
            }
        }

        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { environment.updater.checkForUpdates() }
                .disabled(!environment.updater.canCheckForUpdates)
        }

        CommandGroup(replacing: .newItem) {}

        CommandMenu("File") {
            Button("Search Packages") { environment.state.beginSearch() }
                .keyboardShortcut("k", modifiers: .command)
            Button("Refresh Current Page") { environment.state.requestRefresh() }
                .keyboardShortcut("r", modifiers: .command)
        }

        CommandGroup(replacing: .help) {
            Button("Brewwery Documentation") {
                ExternalLink.open("https://docs.brewwery.com/getting-started")
            }
            Button("Homebrew Website") { ExternalLink.open(AppInfo.homebrewURL) }
        }
    }
}

/// Opens allowlisted URLs with `NSWorkspace`. Nothing else can reach the browser.
enum ExternalLink {
    static func open(_ rawURL: String) {
        guard ExternalLinkPolicy.isAllowed(rawURL), let url = URL(string: rawURL) else {
            Log.app.notice("Blocked an external URL that is not on the allowlist")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Package homepages come from Homebrew rather than from the allowlist, so they are
    /// validated as well-formed http(s) URLs instead.
    static func openHomepage(_ rawURL: String) {
        guard ExternalLinkPolicy.isSafeHomepage(rawURL), let url = URL(string: rawURL) else {
            Log.app.notice("Blocked a malformed package homepage")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
