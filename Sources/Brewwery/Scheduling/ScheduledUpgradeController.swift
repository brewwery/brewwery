import BrewweryCore
import Foundation

/// The Settings side of scheduled upgrades: the preference, the launchd registration and the
/// results the agent leaves behind.
@MainActor
@Observable
final class ScheduledUpgradeController {
    let settings: SettingsStore
    private let service: (any ScheduledUpgradeService)?
    /// Where the agent leaves History entries for the app; `nil` wherever the agent is.
    let inbox: ScheduledUpgradeInbox?

    private(set) var status: ScheduledUpgradeServiceStatus = .notRegistered
    private(set) var lastError: String?

    init(settings: SettingsStore, service: (any ScheduledUpgradeService)?, inbox: ScheduledUpgradeInbox?) {
        self.settings = settings
        self.service = service
        self.inbox = inbox
        refreshStatus()
    }

    /// The packaged app, outside QA profiles.
    static func live(settings: SettingsStore) -> ScheduledUpgradeController {
        let service = LaunchAgentScheduledUpgradeService.makeIfBundled()
        return ScheduledUpgradeController(
            settings: settings,
            service: service,
            inbox: service == nil ? nil : ScheduledUpgradeInbox()
        )
    }

    var isAvailable: Bool { service != nil }

    func refreshStatus() {
        status = service?.status ?? .notRegistered
        settings.reloadScheduledUpgradeLastRun()
    }

    /// Registers the agent. The first run is one interval from now: turning the feature on
    /// must not start upgrading packages under the user's hands.
    func enable() {
        guard let service else { return }
        do {
            try service.register()
            settings.scheduledUpgradeLastRun = Date()
            settings.scheduledUpgradesEnabled = true
            lastError = nil
        } catch {
            Log.app.error("Registering the scheduled-upgrade agent failed: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
        refreshStatus()
    }

    func disable() {
        settings.scheduledUpgradesEnabled = false
        lastError = nil
        if let service, service.status != .notRegistered {
            do {
                try service.unregister()
            } catch {
                Log.app.error("Unregistering the scheduled-upgrade agent failed: \(error.localizedDescription, privacy: .public)")
                lastError = error.localizedDescription
            }
        }
        refreshStatus()
    }

    /// Brings launchd in line with the preference at launch: a copied defaults domain, a
    /// moved app or a reset login-items database can each leave the two disagreeing.
    func reconcile() {
        guard let service else { return }
        let registered = service.status != .notRegistered && service.status != .notFound
        if settings.scheduledUpgradesEnabled, !registered {
            do { try service.register() } catch {
                Log.app.error("Re-registering the scheduled-upgrade agent failed: \(error.localizedDescription, privacy: .public)")
                lastError = error.localizedDescription
            }
        } else if !settings.scheduledUpgradesEnabled, registered {
            try? service.unregister()
        }
        refreshStatus()
    }

    func openLoginItemsSettings() {
        service?.openLoginItemsSettings()
    }
}
