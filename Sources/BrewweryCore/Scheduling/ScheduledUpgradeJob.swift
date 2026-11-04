import Foundation

/// One unattended run: `brew update`, then `brew upgrade` if anything is outdated.
///
/// It returns the History entries the run produced. A run with nothing to upgrade produces
/// none, so a daily schedule does not push real operations out of the 100-entry History.
/// Pinned formulae are left alone by `brew upgrade` itself and are not counted here either.
public enum ScheduledUpgradeJob {
    public static let command = "brew update && brew upgrade"

    public static func run(client: HomebrewClient) async -> [HistoryEntry] {
        do {
            try await client.requireHomebrew()
        } catch {
            return [failure(.upgrade, String(localized: "Scheduled upgrade skipped: Homebrew not found"), error)]
        }

        let update: ProcessOutput
        do {
            update = try await client.updateMetadata()
        } catch {
            return [failure(.brewUpdate, String(localized: "Scheduled upgrade could not update Homebrew"), error, command: "brew update")]
        }

        let outdated: [OutdatedPackage]
        do {
            outdated = try await client.outdated().filter { $0.pinned != true }
        } catch {
            return [failure(.upgrade, String(localized: "Scheduled upgrade could not read outdated packages"), error)]
        }
        guard !outdated.isEmpty else { return [] }

        let upgrade = HomebrewCommand.upgradeAll
        let events: AsyncStream<OperationEvent>
        do {
            events = try await client.stream(upgrade, kind: .upgrade, id: UUID())
        } catch {
            return [failure(.upgrade, String(localized: "Scheduled upgrade failed"), error)]
        }

        let details = outdated
            .map { "\($0.name) \($0.currentVersion ?? "?") → \($0.latestVersion ?? "?")" }
            .joined(separator: "\n")
        for await event in events {
            switch event {
            case .completed(let stdout, let stderr, _, _):
                return [HistoryEntry(
                    kind: .upgrade,
                    status: .success,
                    title: String(localized: "Scheduled upgrade finished"),
                    command: command,
                    stdout: [update.stdout.trimmed, stdout].filter { !$0.isEmpty }.joined(separator: "\n\n"),
                    stderr: stderr.isEmpty ? nil : stderr,
                    details: details
                )]
            case .failed(let stdout, let stderr, _, let error, _):
                let title = error.code == .operationTimeout
                    ? String(localized: "Scheduled upgrade timed out")
                    : String(localized: "Scheduled upgrade failed")
                return [HistoryEntry(
                    kind: .upgrade,
                    status: .failed,
                    title: title,
                    command: command,
                    stdout: stdout.isEmpty ? nil : stdout,
                    stderr: stderr.isEmpty ? error.raw : stderr,
                    details: details,
                    error: error
                )]
            case .started, .output:
                continue
            }
        }
        return [failure(.upgrade, String(localized: "Scheduled upgrade failed"),
                        BrewweryError(code: .unknownError, message: "The Homebrew operation produced no result."))]
    }

    private static func failure(
        _ kind: HistoryOperationKind,
        _ title: String,
        _ error: BrewweryError,
        command: String = command
    ) -> HistoryEntry {
        HistoryEntry(kind: kind, status: .failed, title: title, command: command, stderr: error.raw, error: error)
    }
}
