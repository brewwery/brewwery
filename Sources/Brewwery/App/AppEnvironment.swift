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
        favorites: FavoritesStore = FavoritesStore(),
        updateDriver: (any AppUpdateDriver)? = SparkleUpdateDriver.makeIfConfigured()
    ) {
        let state = AppState()
        let operations = OperationCoordinator(client: client)

        self.settings = settings
        self.client = client
        self.state = state
        self.history = history
        self.favorites = favorites
        self.operations = operations
        self.system = SystemModel(client: client)
        self.library = PackageLibrary(client: client)
        self.updates = UpdatesModel(client: client, operations: operations)
        self.services = ServicesModel(client: client)
        self.taps = TapsModel(client: client, operations: operations)
        self.cleanup = CleanupModel(client: client)
        self.doctor = DoctorModel(client: client)
        self.brewfile = BrewfileModel(client: client)
        self.updater = AppUpdateController(settings: settings, driver: updateDriver)
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
        guard !system.isHomebrewMissing else { return }

        // The status bar and every "Installed" badge read the installed lists, and the Dock
        // badge, the sidebar and the menu bar all read the outdated list, so both load at
        // launch rather than waiting for a page that happens to request them. Without this
        // the Dock could claim four updates while the window showed nothing at all.
        await withTaskGroup { group in
            group.addTask { await self.library.loadAll() }
            group.addTask { await self.updates.refresh(silently: true) }
        }
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
        successTitle: LocalizedStringResource,
        failureTitle: @escaping (BrewweryError) -> LocalizedStringResource,
        details: ((_ stdout: String) -> String?)? = nil
    ) async -> Bool {
        let displayCommand = command.displayCommand()

        do {
            let outcome = try await operations.run(command, kind: kind, target: target)

            let succeeded: Bool
            switch outcome {
            case .completed(let stdout, let stderr):
                record(
                    HistoryEntry(
                        kind: historyKind,
                        status: .success,
                        title: String(localized: successTitle),
                        command: displayCommand,
                        target: target,
                        stdout: stdout,
                        stderr: stderr,
                        details: details?(stdout)
                    )
                )
                succeeded = true

            case .failed(let error, let stdout, let stderr):
                record(
                    HistoryEntry(
                        kind: historyKind,
                        status: error.code == .operationCancelled ? .cancelled : .failed,
                        title: String(localized: failureTitle(error)),
                        command: displayCommand,
                        target: target,
                        stdout: stdout,
                        stderr: stderr.isEmpty ? error.raw : stderr,
                        error: error
                    )
                )
                succeeded = false
            }
            // Record the result immediately; a cache refresh may itself be slow or fail.
            // Failed and cancelled operations may already have changed Homebrew.
            switch kind {
            case .install, .uninstall, .upgrade: await invalidateAfterPackageChange()
            case .service: await Task { await services.refresh() }.value
            default: break
            }
            return succeeded
        } catch {
            record(
                HistoryEntry(
                    kind: historyKind,
                    status: .failed,
                    title: String(localized: failureTitle(error)),
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

    func flushPersistence() async -> Bool {
        async let savedHistory = history.flushPersistence()
        async let savedFavorites = favorites.flushPersistence()
        let results = await (savedHistory, savedFavorites)
        return results.0 && results.1
    }

    /// Refreshes the caches that a package mutation invalidates.
    func invalidateAfterPackageChange() async {
        // Reconcile partial changes even when the mutation's calling task was cancelled.
        await Task {
            await library.loadAll()
            await updates.refresh()
        }.value
    }
}
