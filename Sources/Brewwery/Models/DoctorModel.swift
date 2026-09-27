import BrewweryCore
import SwiftUI

/// `hooks/use-doctor.ts`.
@MainActor
@Observable
final class DoctorModel {
    private(set) var result: DoctorResult?
    private(set) var isRunning = false
    private(set) var error: BrewweryError?

    private let client: HomebrewClient

    init(client: HomebrewClient) {
        self.client = client
    }

    /// Runs `brew doctor` and returns the history entry describing the run.
    func run() async -> HistoryEntry {
        isRunning = true
        error = nil
        defer { isRunning = false }

        do {
            let result = try await client.doctor()
            self.result = result
            return HistoryEntry(
                kind: .doctor,
                status: .success,
                title: result.healthy ? String(localized: "Doctor completed: healthy") : String(localized: "Doctor completed with diagnostics"),
                command: "brew doctor",
                stdout: result.rawOutput,
                details: String(localized: "\(result.diagnostics.count) diagnostics")
            )
        } catch {
            self.error = error
            return HistoryEntry(
                kind: .doctor,
                status: .failed,
                title: String(localized: "Doctor failed"),
                command: "brew doctor",
                stderr: error.raw,
                error: error
            )
        }
    }
}
