import BrewweryCore
import SwiftUI

/// `hooks/use-cleanup.ts`.
///
/// Cleanup is preview-first by design: `brew cleanup` is only reachable after
/// `brew cleanup -n` has listed what would be removed.
@MainActor
@Observable
final class CleanupModel {
    private(set) var preview: CleanupPreview?
    private(set) var result: CleanupResult?
    private(set) var isPreviewing = false
    private(set) var error: BrewweryError?

    private let client: HomebrewClient

    init(client: HomebrewClient) {
        self.client = client
    }

    /// The Run button stays disabled until a preview has found something to remove.
    var canRunCleanup: Bool { (preview?.items.isEmpty == false) }

    func loadPreview() async {
        isPreviewing = true
        error = nil
        result = nil
        defer { isPreviewing = false }

        do {
            preview = try await client.cleanupPreview()
        } catch {
            self.error = error
        }
    }

    func applyResult(_ result: CleanupResult) {
        self.result = result
        preview = nil
    }

    func applyFailure(_ error: BrewweryError) {
        self.error = error
    }
}
