import Foundation
import Observation

/// User-facing appearance preference (`settings-store.theme`).
public enum AppTheme: String, Codable, Sendable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    public var id: String { rawValue }
    /// The legacy buttons render the raw lowercase value.
    public var displayName: String { rawValue }
}

/// Persisted preferences.
///
/// The legacy app split these across two stores — a renderer `localStorage` store and a
/// main-process `settings.json` holding only `homebrewPath`. Natively there is one owner:
/// `UserDefaults`, which also gives the app free state restoration and defaults management.
/// The custom Homebrew path keeps exactly the same semantics: stored as typed, applied to
/// the detector at launch, and dropped if it no longer validates.
@MainActor
@Observable
public final class SettingsStore {
    public enum Key {
        public static let theme = "brewwery.theme"
        public static let showPrereleaseUpdates = "brewwery.showPrereleaseUpdates"
        public static let customHomebrewPath = "brewwery.customHomebrewPath"
        public static let automaticallyCheckForUpdates = "brewwery.automaticallyCheckForUpdates"
        public static let showDockBadge = "brewwery.showDockBadge"
        public static let scheduledUpgradesEnabled = "brewwery.scheduledUpgradesEnabled"
        public static let scheduledUpgradeInterval = "brewwery.scheduledUpgradeInterval"
        public static let scheduledUpgradeLastRun = "brewwery.scheduledUpgradeLastRun"
    }

    private let defaults: UserDefaults

    public var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    public var showPrereleaseUpdates: Bool {
        didSet { defaults.set(showPrereleaseUpdates, forKey: Key.showPrereleaseUpdates) }
    }

    /// Empty string means "auto-detect", matching the legacy field.
    public var customHomebrewPath: String {
        didSet { defaults.set(customHomebrewPath, forKey: Key.customHomebrewPath) }
    }

    public var automaticallyCheckForUpdates: Bool {
        didSet { defaults.set(automaticallyCheckForUpdates, forKey: Key.automaticallyCheckForUpdates) }
    }

    /// Whether the number of outdated packages appears on the Dock icon. On by default,
    /// as in 0.9.7, but a badge nobody can explain is worse than no badge.
    public var showDockBadge: Bool {
        didSet { defaults.set(showDockBadge, forKey: Key.showDockBadge) }
    }

    /// The user's choice to let the background agent run `brew update` and `brew upgrade`.
    /// Off by default: turning it on is the confirmation every Homebrew mutation requires.
    public var scheduledUpgradesEnabled: Bool {
        didSet { defaults.set(scheduledUpgradesEnabled, forKey: Key.scheduledUpgradesEnabled) }
    }

    public var scheduledUpgradeInterval: ScheduledUpgradeInterval {
        didSet { defaults.set(scheduledUpgradeInterval.rawValue, forKey: Key.scheduledUpgradeInterval) }
    }

    /// Written by the background agent, which runs in its own process. The app reads it again
    /// with `reloadScheduledUpgradeLastRun()` whenever the agent reports back.
    public var scheduledUpgradeLastRun: Date? {
        didSet { defaults.set(scheduledUpgradeLastRun, forKey: Key.scheduledUpgradeLastRun) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 0.9.7 shipped with dark as the default, not "system".
        self.theme = defaults.string(forKey: Key.theme).flatMap(AppTheme.init) ?? .dark
        self.showPrereleaseUpdates = defaults.bool(forKey: Key.showPrereleaseUpdates)
        self.customHomebrewPath = defaults.string(forKey: Key.customHomebrewPath) ?? ""
        self.automaticallyCheckForUpdates = defaults.object(forKey: Key.automaticallyCheckForUpdates) as? Bool ?? true
        self.showDockBadge = defaults.object(forKey: Key.showDockBadge) as? Bool ?? true
        self.scheduledUpgradesEnabled = defaults.bool(forKey: Key.scheduledUpgradesEnabled)
        self.scheduledUpgradeInterval = defaults.string(forKey: Key.scheduledUpgradeInterval)
            .flatMap(ScheduledUpgradeInterval.init) ?? .daily
        self.scheduledUpgradeLastRun = defaults.object(forKey: Key.scheduledUpgradeLastRun) as? Date
    }

    public func resetCustomHomebrewPath() {
        customHomebrewPath = ""
    }

    public func reloadScheduledUpgradeLastRun() {
        let stored = defaults.object(forKey: Key.scheduledUpgradeLastRun) as? Date
        if stored != scheduledUpgradeLastRun { scheduledUpgradeLastRun = stored }
    }
}
