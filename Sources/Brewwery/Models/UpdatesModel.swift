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

    var formulaeCount: Int { updates.count { $0.kind == .formula } }
    var casksCount: Int { updates.count { $0.kind == .cask } }

    /// Reads the outdated list. This does **not** refresh Homebrew's metadata.
    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            updates = try await client.outdated()
            lastChecked = Date()
        } catch {
            self.error = error
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
