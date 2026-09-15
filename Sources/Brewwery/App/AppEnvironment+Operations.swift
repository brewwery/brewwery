import BrewweryCore
import SwiftUI

/// The mutating flows, in one place.
///
/// Each one is confirmation-gated in the UI, runs through `OperationCoordinator` so only a
/// single mutating Homebrew command is ever in flight, streams its output, records history,
/// raises a toast and invalidates the caches the change affects.
extension AppEnvironment {

    // MARK: - Packages

    func installPackage(_ reference: PackageReference) async {
        let succeeded = await runOperation(
            .install(reference),
            kind: .install,
            historyKind: .install,
            target: reference.name,
            successTitle: "Installed \(reference.name)",
            failureTitle: { error in
                switch error.code {
                case .operationCancelled: "Cancelled install of \(reference.name)"
                case .operationTimeout: "Timed out while running install for \(reference.name)"
                default: "Failed to install \(reference.name)"
                }
            }
        )
        if succeeded { await invalidateAfterPackageChange() }
    }

    func uninstallPackage(_ reference: PackageReference) async {
        let succeeded = await runOperation(
            .uninstall(reference),
            kind: .uninstall,
            historyKind: .uninstall,
            target: reference.name,
            successTitle: "Uninstalled \(reference.name)",
            failureTitle: { error in
                switch error.code {
                case .operationCancelled: "Cancelled uninstall of \(reference.name)"
                case .operationTimeout: "Timed out while running uninstall for \(reference.name)"
                default: "Failed to uninstall \(reference.name)"
                }
            }
        )
        if succeeded { await invalidateAfterPackageChange() }
    }

    // MARK: - Updates

    /// Upgrades one package. Distinct from `refreshMetadata()`, which only updates
    /// Homebrew's own metadata.
    func upgradePackage(_ reference: PackageReference) async {
        let succeeded = await runOperation(
            .upgrade(reference),
            kind: .upgrade,
            historyKind: .upgrade,
            target: reference.name,
            successTitle: "Upgraded \(reference.name)",
            failureTitle: { error in
                switch error.code {
                case .operationCancelled: "Cancelled upgrade of \(reference.name)"
                case .operationTimeout: "Upgrade timed out for \(reference.name)"
                default: "Failed to upgrade \(reference.name)"
                }
            }
        )
        if succeeded { await invalidateAfterPackageChange() }
    }

    func upgradeAllPackages() async {
        let succeeded = await runOperation(
            .upgradeAll,
            kind: .upgrade,
            historyKind: .upgrade,
            target: nil,
            successTitle: "Upgraded all outdated packages",
            failureTitle: { error in
                switch error.code {
                case .operationCancelled: "Cancelled upgrade of all packages"
                case .operationTimeout: "Upgrade timed out for all packages"
                default: "Failed to upgrade all packages"
                }
            }
        )
        if succeeded { await invalidateAfterPackageChange() }
    }

    /// `brew update` — refreshes Homebrew's metadata only. Never confused with upgrading
    /// installed packages.
    func refreshHomebrewMetadata() async {
        switch await updates.updateMetadata() {
        case .success(let output):
            record(
                HistoryEntry(
                    kind: .brewUpdate,
                    status: .success,
                    title: "Updated Homebrew metadata",
                    command: "brew update",
                    stdout: output.stdout.nilIfBlank,
                    stderr: output.stderr.nilIfBlank
                )
            )
            await updates.refresh()
        case .failure(let error):
            record(
                HistoryEntry(
                    kind: .brewUpdate,
                    status: .failed,
                    title: "Failed to update Homebrew metadata",
                    command: "brew update",
                    stderr: error.raw,
                    error: error
                )
            )
        }
    }

    // MARK: - Services

    func performServiceAction(_ action: ServiceAction, on name: String) async {
        let succeeded = await runOperation(
            .service(action: action, name: name),
            kind: .service,
            historyKind: .service,
            target: name,
            successTitle: "\(action.rawValue.capitalized) \(name)",
            failureTitle: { error in
                switch error.code {
                case .operationCancelled: "Cancelled \(action.rawValue) for \(name)"
                case .operationTimeout: "Service \(action.rawValue) timed out for \(name)"
                default: "Failed to \(action.rawValue) \(name)"
                }
            }
        )
        if succeeded { await services.refresh() }
    }

    // MARK: - Taps

    /// Taps run buffered rather than streamed, exactly as in 0.9.7 — `brew tap` is quick and
    /// produces little output.
    func performTapAction(_ action: TapAction, name: String) async {
        let command = action == .tap
            ? HomebrewCommand.addTap(name: name)
            : HomebrewCommand.removeTap(name: name)

        switch await taps.perform(action, name: name) {
        case .success(let output):
            record(
                HistoryEntry(
                    kind: .tap,
                    status: .success,
                    title: action == .tap ? "Added tap \(name)" : "Removed tap \(name)",
                    command: command.displayCommand(),
                    target: name,
                    stdout: output.stdout.nilIfBlank,
                    stderr: output.stderr.nilIfBlank
                )
            )
        case .failure(let error):
            record(
                HistoryEntry(
                    kind: .tap,
                    status: .failed,
                    title: action == .tap ? "Failed to add tap \(name)" : "Failed to remove tap \(name)",
                    command: command.displayCommand(),
                    target: name,
                    stderr: error.raw,
                    error: error
                )
            )
        }
    }

    // MARK: - Cleanup

    func runCleanup() async {
        do {
            let outcome = try await operations.run(.cleanup, kind: .cleanup)

            switch outcome {
            case .completed(let stdout, let stderr):
                let result = CleanupResult(
                    success: true,
                    removedItems: CleanupParser.countRemovals(stdout),
                    freedSpace: CleanupParser.findFreedSpace(stdout),
                    stdout: stdout.nilIfBlank,
                    stderr: stderr.nilIfBlank
                )
                cleanup.applyResult(result)
                record(
                    HistoryEntry(
                        kind: .cleanup,
                        status: .success,
                        title: "Cleanup completed",
                        command: "brew cleanup",
                        stdout: result.stdout,
                        stderr: result.stderr,
                        details: [
                            result.removedItems.map { "\($0) removal operations" },
                            result.freedSpace.map { "\($0) freed" }
                        ]
                        .compactMap { $0 }
                        .joined(separator: " · ")
                        .nilIfBlank
                    )
                )

            case .failed(let error, let stdout, let stderr):
                cleanup.applyFailure(error)
                let title = switch error.code {
                case .operationCancelled: "Cleanup cancelled"
                case .operationTimeout: "Cleanup timed out"
                default: "Cleanup failed"
                }
                record(
                    HistoryEntry(
                        kind: .cleanup,
                        status: error.code == .operationCancelled ? .cancelled : .failed,
                        title: title,
                        command: "brew cleanup",
                        stdout: stdout.nilIfBlank,
                        stderr: stderr.nilIfBlank ?? error.raw,
                        error: error
                    )
                )
            }
        } catch {
            cleanup.applyFailure(error)
            record(
                HistoryEntry(
                    kind: .cleanup,
                    status: .failed,
                    title: "Cleanup failed",
                    command: "brew cleanup",
                    stderr: error.raw,
                    error: error
                )
            )
        }
    }

    // MARK: - Doctor and Brewfile

    func runDoctor() async {
        record(await doctor.run())
    }

    func exportBrewfile() async {
        record(await brewfile.export())
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
