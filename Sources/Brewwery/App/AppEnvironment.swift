import BrewweryCore
import SwiftUI

/// Composition root.
///
/// Everything the app needs is built once here and handed down through the SwiftUI
/// environment. The legacy app created a fresh hook instance per page, so opening the
/// Dashboard re-ran five Homebrew queries that other pages had already run; holding one
/// instance of each model keeps the same data on screen with fewer `brew` invocations.
@MainActor
@Observable
final class AppEnvironment {
    let client: HomebrewClient
    let settings: SettingsStore
    let history: HistoryStore
    let favorites: FavoritesStore
    let operations: OperationCoordinator
    let state: AppState

    let system: SystemModel
    let library: PackageLibrary
    let updates: UpdatesModel
    let services: ServicesModel
    let taps: TapsModel
    let cleanup: CleanupModel
    let doctor: DoctorModel
    let brewfile: BrewfileModel
    let updater: AppUpdateController

    init(
        client: HomebrewClient = HomebrewClient(),
        settings: SettingsStore = SettingsStore(),
        history: HistoryStore = HistoryStore(),
        favorites: FavoritesStore = FavoritesStore()
    ) {
        let state = AppState()

        self.settings = settings
        self.client = client
        self.state = state
        self.history = history
        self.favorites = favorites
        self.operations = OperationCoordinator(client: client)
        self.system = SystemModel(client: client)
        self.library = PackageLibrary(client: client)
        self.updates = UpdatesModel(client: client)
        self.services = ServicesModel(client: client)
        self.taps = TapsModel(client: client)
        self.cleanup = CleanupModel(client: client)
        self.doctor = DoctorModel(client: client)
        self.brewfile = BrewfileModel(client: client)
        self.updater = AppUpdateController(settings: settings)
    }

    /// Applies the stored custom Homebrew path before the first query runs, so a user who
    /// keeps Homebrew outside the standard prefixes never sees a "not found" flash.
    func prepare() async {
        let stored = settings.customHomebrewPath
        let validation = await client.detector.applyStoredCustomPath(stored.isEmpty ? nil : stored)
        if let validation, !validation.valid {
            Log.app.notice("Stored Homebrew path is no longer usable; falling back to detection")
            settings.resetCustomHomebrewPath()
        }
        await system.load()
    }

    // MARK: - Shared operation plumbing

    /// Runs a streaming operation, records it in history, raises the matching toast and
    /// returns whether it succeeded.
    ///
    /// Every mutating flow funnels through here so that history, toasts, cancellation and
    /// the "another operation is running" guard behave identically no matter which page
    /// started the work.
    @discardableResult
    func runOperation(
        _ command: HomebrewCommand,
        kind: OperationKind,
        historyKind: HistoryOperationKind,
        target: String?,
        successTitle: String,
        failureTitle: @escaping (BrewweryError) -> String,
        details: ((_ stdout: String) -> String?)? = nil
    ) async -> Bool {
        let displayCommand = command.displayCommand()

        do {
            let outcome = try await operations.run(command, kind: kind, target: target)

            switch outcome {
            case .completed(let stdout, let stderr):
                record(
                    HistoryEntry(
                        kind: historyKind,
                        status: .success,
                        title: successTitle,
                        command: displayCommand,
                        target: target,
                        stdout: stdout,
                        stderr: stderr,
                        details: details?(stdout)
                    )
                )
                return true

            case .failed(let error, let stdout, let stderr):
                record(
                    HistoryEntry(
                        kind: historyKind,
                        status: error.code == .operationCancelled ? .cancelled : .failed,
                        title: failureTitle(error),
                        command: displayCommand,
                        target: target,
                        stdout: stdout,
                        stderr: stderr.isEmpty ? error.raw : stderr,
                        error: error
                    )
                )
                return false
            }
        } catch {
            record(
                HistoryEntry(
                    kind: historyKind,
                    status: .failed,
                    title: failureTitle(error),
                    command: displayCommand,
                    target: target,
                    stderr: error.raw,
                    error: error
                )
            )
            return false
        }
    }

    /// Records a history entry and surfaces it as a toast.
    func record(_ entry: HistoryEntry) {
        let stored = history.add(entry)
        state.show(historyEntry: stored)
    }

    /// Refreshes the caches that a package mutation invalidates.
    func invalidateAfterPackageChange() async {
        await library.loadAll()
        await updates.refresh()
    }
}
