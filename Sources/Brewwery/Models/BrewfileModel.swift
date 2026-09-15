import BrewweryCore
import SwiftUI

/// `hooks/use-brewfile.ts`.
@MainActor
@Observable
final class BrewfileModel {
    private(set) var document: BrewfileDocument?
    private(set) var isWorking = false
    private(set) var error: BrewweryError?

    private let client: HomebrewClient

    init(client: HomebrewClient) {
        self.client = client
    }

    func groupedEntries() -> [BrewfileEntryKind: [BrewfileEntry]] {
        Dictionary(grouping: document?.entries ?? [], by: \.kind)
    }

    /// `brew bundle dump --force --file=<temp>` followed by a read-back of the result.
    func export() async -> HistoryEntry {
        isWorking = true
        error = nil
        defer { isWorking = false }

        let command = "brew bundle dump --force --file=<temp>"

        do {
            let document = try await client.exportBrewfile()
            self.document = document
            return HistoryEntry(
                kind: .brewfileExport,
                status: .success,
                title: "Brewfile exported",
                command: command,
                target: document.path,
                stdout: document.rawContent,
                details: "\(document.entries.count) entries"
            )
        } catch {
            self.error = error
            return HistoryEntry(
                kind: .brewfileExport,
                status: .failed,
                title: "Brewfile export failed",
                command: command,
                stderr: error.raw,
                error: error
            )
        }
    }

    /// Reads a Brewfile the user chose. Reading is not logged to history — the legacy app
    /// logged exports only, because a read changes nothing.
    func read(at path: String) async {
        isWorking = true
        error = nil
        defer { isWorking = false }

        do {
            document = try await client.readBrewfile(at: path)
        } catch {
            self.error = error
        }
    }
}
