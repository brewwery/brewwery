import BrewweryCore
import SwiftUI

/// `hooks/use-system.ts` — Homebrew detection plus `brew config` metadata.
@MainActor
@Observable
final class SystemModel {
    private(set) var detection: BrewDetectionResult?
    private(set) var info: BrewInfo?
    private(set) var error: BrewweryError?
    private(set) var isLoading = true

    private let client: HomebrewClient

    #if DEBUG
    /// Screenshot runs show a conventional executable path instead of the demo script's.
    var displayedExecutableOverride: String?
    #endif

    init(client: HomebrewClient) {
        self.client = client
    }

    var isHomebrewMissing: Bool { detection?.found == false }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let detection = await client.detect()
        self.detection = detection

        guard detection.found else {
            error = detection.error
            info = nil
            return
        }

        do {
            info = try await client.brewInfo()
            error = nil
        } catch {
            self.error = error
        }

        #if DEBUG
        if let displayedExecutableOverride {
            self.detection?.path = displayedExecutableOverride
            self.detection?.checkedPaths = HomebrewDetector.standardPaths + ["PATH"]
            info?.path = displayedExecutableOverride
        }
        #endif
    }
}
