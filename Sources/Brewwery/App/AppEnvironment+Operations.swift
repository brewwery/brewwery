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
                    title: String(localized: "Updated Homebrew metadata"),
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
                    title: String(localized: "Failed to update Homebrew metadata"),
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
            successTitle: action.successTitle(name),
            failureTitle: { error in action.failureTitle(name, code: error.code) }
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
                    title: action == .tap ? String(localized: "Added tap \(name)") : String(localized: "Removed tap \(name)"),
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
                    title: action == .tap ? String(localized: "Failed to add tap \(name)") : String(localized: "Failed to remove tap \(name)"),
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
                        title: String(localized: "Cleanup completed"),
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
                case .operationCancelled: String(localized: "Cleanup cancelled")
                case .operationTimeout: String(localized: "Cleanup timed out")
                default: String(localized: "Cleanup failed")
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
                    title: String(localized: "Cleanup failed"),
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

    /// `brew pin` or `brew unpin` one formula.
    ///
    /// Quick, so it runs without the progress panel, but it is still a change to Homebrew:
    /// it waits for any running operation, is confirmed by the caller, and lands in History.
    func setPinned(_ pinned: Bool, formula: String) async {
        guard !operations.isRunning else {
            state.show(Toast(tone: .error, title: "Another Homebrew operation is running", description: "Try again when it finishes."))
            return
        }
        let command = pinned ? HomebrewCommand.pin(formula: formula) : HomebrewCommand.unpin(formula: formula)

        do {
            let output = try await client.setPinned(pinned, formula: formula)
            record(
                HistoryEntry(
                    kind: .pin,
                    status: .success,
                    title: pinned ? String(localized: "Pinned \(formula)") : String(localized: "Unpinned \(formula)"),
                    command: command.displayCommand(),
                    target: formula,
                    stdout: output.stdout.nilIfBlank,
                    stderr: output.stderr.nilIfBlank
                )
            )
        } catch {
            record(
                HistoryEntry(
                    kind: .pin,
                    status: .failed,
                    title: pinned ? String(localized: "Failed to pin \(formula)") : String(localized: "Failed to unpin \(formula)"),
                    command: command.displayCommand(),
                    target: formula,
                    stderr: error.raw,
                    error: error
                )
            )
        }

        await library.reloadPinned()
        // `brew outdated` reports the pinned flag, and the count leaves pinned formulae out.
        await updates.refresh(silently: true)
    }

    /// Compares the open Brewfile with this Mac.
    func checkBrewfile() async {
        if library.formulae.isEmpty, library.casks.isEmpty { await library.loadAll() }
        await brewfile.check(formulae: library.formulae, casks: library.casks)
    }

    /// Installs what the open Brewfile lists and this Mac lacks, as one streaming operation.
    ///
    /// Homebrew never sees the user's file: Brewwery writes the missing items, one validated
    /// name per line, to its own list and installs from that. Nothing is upgraded.
    func installMissingFromBrewfile() async {
        guard let plan = brewfile.plan, !plan.missing.isEmpty else { return }

        let path: String
        do {
            path = try plan.writeInstallFile()
        } catch {
            state.show(Toast(tone: .error, title: "Could not prepare the install", description: "\(error.friendlyMessage)"))
            return
        }
        defer { try? FileManager.default.removeItem(atPath: path) }

        let count = plan.missing.count
        let succeeded = await runOperation(
            .bundleInstall(path: path),
            kind: .bundle,
            historyKind: .brewfileInstall,
            target: plan.missing.map(\.name).joined(separator: ", "),
            // A plural-aware key: the catalog carries one/few/many forms per language.
            successTitle: "Installed \(count) items from Brewfile",
            failureTitle: { error in
                switch error.code {
                case .operationCancelled: "Cancelled Brewfile install"
                case .operationTimeout: "Brewfile install timed out"
                default: "Brewfile install failed"
                }
            }
        )

        // Even a failed run may have installed some of the list, so re-read either way.
        await invalidateAfterPackageChange()
        if plan.missing.contains(where: { $0.kind == .tap }) { await taps.refresh() }
        await checkBrewfile()
        _ = succeeded
    }
}

extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
