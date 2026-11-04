import BrewweryCore
import Foundation

/// `Brewwery --scheduled-upgrade`, started by launchd while the app may be closed.
///
/// It never shows UI. It runs only when the user turned the schedule on and the interval has
/// elapsed, takes the cross-process mutation lock so it cannot overlap an operation in the
/// app, and leaves its History entries in the inbox for the app to import.
@MainActor
enum ScheduledUpgradeAgent {
    static let argument = "--scheduled-upgrade"
    /// Lets an open app import the result straight away instead of on next activation.
    static let finishedNotification = Notification.Name("com.brewwery.app.scheduledUpgradeFinished")

    static func run(
        settings: SettingsStore = SettingsStore(),
        lock: MutationLock = .applicationSupport,
        inbox: ScheduledUpgradeInbox = ScheduledUpgradeInbox(),
        // No lock of its own: `run` holds `lock` for the whole job, and a second flock on a new
        // descriptor from this same process would report the agent as busy against itself.
        client: HomebrewClient = HomebrewClient(),
        now: @escaping () -> Date = Date.init
    ) async -> Int32 {
        guard settings.scheduledUpgradesEnabled else {
            Log.app.info("Scheduled upgrade skipped: turned off")
            return 0
        }
        guard ScheduledUpgradeSchedule.isDue(
            lastRun: settings.scheduledUpgradeLastRun,
            interval: settings.scheduledUpgradeInterval,
            now: now()
        ) else {
            Log.app.info("Scheduled upgrade skipped: not due")
            return 0
        }
        guard let token = lock.tryAcquire() else {
            // Not recorded as a run, so the next hourly start tries again.
            Log.app.notice("Scheduled upgrade deferred: another Homebrew change is running")
            return 0
        }
        defer { token.release() }

        // Apply, but never reset: clearing the user's path is the app's call, with the user present.
        let stored = settings.customHomebrewPath
        _ = await client.detector.applyStoredCustomPath(stored.isEmpty ? nil : stored)

        Log.app.notice("Scheduled upgrade started")
        let entries = await ScheduledUpgradeJob.run(client: client)
        if !entries.isEmpty {
            do {
                try inbox.deliver(entries, at: now())
            } catch {
                // Not recorded as a run: the next hourly start repeats it and tries to deliver again,
                // rather than the user never hearing about this one.
                Log.persistence.error("Scheduled upgrade could not store its result: \(error.localizedDescription, privacy: .public)")
                return 1
            }
        }
        settings.scheduledUpgradeLastRun = now()

        DistributedNotificationCenter.default().postNotificationName(
            finishedNotification,
            object: AppInfo.bundleIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
        Log.app.notice("Scheduled upgrade finished with \(entries.count, privacy: .public) History entries")
        return 0
    }
}
