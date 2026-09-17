import BrewweryCore
import SwiftUI

/// `hooks/use-updates.ts` — the outdated list and the `brew update` / `brew upgrade`
/// distinction.
@MainActor
@Observable
final class UpdatesModel {
    private(set) var updates: [OutdatedPackage] = []
    private(set) var isLoading = true
    private(set) var error: BrewweryError?
    private(set) var lastChecked: Date?

    private let client: HomebrewClient

    init(client: HomebrewClient) {
        self.client = client
    }

    /// The number the Dock badge, the sidebar, the status bar and the menu bar all show.
    /// Keeping them on one property is what stops them from disagreeing.
    var count: Int { updates.count }
    var formulaeCount: Int { updates.count { $0.kind == .formula } }
    var casksCount: Int { updates.count { $0.kind == .cask } }

    /// Reads the outdated list. This does **not** refresh Homebrew's metadata.
    ///
    /// A `silent` refresh leaves `isLoading` alone and keeps the previous list on screen
    /// if it fails: it is what the periodic background check uses, and a page the user is
    /// reading should not flash a skeleton every half hour.
    func refresh(silently: Bool = false) async {
        if !silently { isLoading = true }
        error = nil
        // Cleared either way: a silent refresh does not raise the skeleton, but once it has
        // answered, the page is no longer loading.
        defer { isLoading = false }

        do {
            updates = try await client.outdated()
            lastChecked = Date()
        } catch {
            if !silently { self.error = error }
            Log.updates.notice("Background outdated check failed: \(error.code.rawValue, privacy: .public)")
        }
    }

    /// `brew update` — refreshes Homebrew's own metadata, never the installed packages.
    /// Returns the command output so the caller can log it.
    func updateMetadata() async -> Result<ProcessOutput, BrewweryError> {
        do {
            let output = try await client.updateMetadata()
            return .success(output)
        } catch {
            self.error = error
            return .failure(error)
        }
    }
}
