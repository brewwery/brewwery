import BrewweryCore
import SwiftUI

/// Where the open Brewfile came from.
enum BrewfileSource: Equatable {
    case exported
    case file(String)
    case starter(String)

    var displayName: LocalizedStringResource {
        switch self {
        case .exported: "This Mac's current setup"
        case .file(let path): "\(path)"
        case .starter(let title): "Starter: \(title)"
        }
    }

    var contentsTitle: LocalizedStringResource {
        switch self {
        case .exported: "Generated Brewfile"
        case .file: "Brewfile contents"
        case .starter: "Starter contents"
        }
    }
}

/// `hooks/use-brewfile.ts`.
@MainActor
@Observable
final class BrewfileModel {
    private(set) var document: BrewfileDocument?
    /// Where `document` came from, shown above the comparison.
    private(set) var source: BrewfileSource?
    private(set) var isWorking = false
    private(set) var error: BrewweryError?

    /// The open Brewfile compared with this Mac. Recomputed whenever the document or the
    /// installed lists change; `nil` until a Brewfile is open.
    private(set) var plan: BrewfilePlan?
    private(set) var isChecking = false

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
            source = .exported
            plan = nil
            return HistoryEntry(
                kind: .brewfileExport,
                status: .success,
                title: String(localized: "Brewfile exported"),
                command: command,
                target: document.path,
                stdout: document.rawContent,
                details: String(localized: "\(document.entries.count) entries")
            )
        } catch {
            self.error = error
            return HistoryEntry(
                kind: .brewfileExport,
                status: .failed,
                title: String(localized: "Brewfile export failed"),
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
            source = .file(path)
            plan = nil
        } catch {
            self.error = error
        }
    }

    /// Opens one of the bundled starter Brewfiles, so it can be compared and installed
    /// like a file from disk.
    func open(starter: StarterBrewfile) {
        error = nil
        document = BrewfileDocument(path: nil, entries: BrewfileParser.parse(starter.content), rawContent: starter.content)
        source = .starter(String(localized: starter.title))
        plan = nil
    }

    /// Compares the open Brewfile with what is installed. Local only: Brewwery's own parse
    /// against the lists it already holds, plus `brew tap` for the taps.
    func check(formulae: [Formula], casks: [Cask]) async {
        guard let document else { plan = nil; return }
        isChecking = true
        defer { isChecking = false }

        let taps = (try? await client.taps()) ?? []
        plan = BrewfilePlan.make(
            entries: document.entries,
            installedFormulae: formulae,
            installedCasks: casks,
            installedTaps: taps
        )
    }
}
