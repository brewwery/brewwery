import Foundation

/// How often the background agent upgrades Homebrew packages.
///
/// The launch agent itself wakes every hour; the interval is a preference it checks, so
/// changing it never re-registers anything with launchd.
public enum ScheduledUpgradeInterval: String, Codable, Sendable, CaseIterable, Identifiable {
    case sixHours
    case twelveHours
    case daily
    case weekly

    public var id: String { rawValue }

    public var duration: TimeInterval {
        switch self {
        case .sixHours: 6 * 3600
        case .twelveHours: 12 * 3600
        case .daily: 24 * 3600
        case .weekly: 7 * 24 * 3600
        }
    }
}

/// Decides whether a scheduled run is due.
public enum ScheduledUpgradeSchedule {
    /// launchd fires the agent roughly hourly, never exactly on the hour mark of the last run.
    /// Without slack a daily run would slip by up to an hour every day.
    public static let tolerance: TimeInterval = 10 * 60

    public static func isDue(lastRun: Date?, interval: ScheduledUpgradeInterval, now: Date = Date()) -> Bool {
        guard let lastRun else { return true }
        let elapsed = now.timeIntervalSince(lastRun)
        // A last run in the future means the clock moved back; waiting for it would stall
        // upgrades for as long as the clock was wrong.
        if elapsed < -tolerance { return true }
        return elapsed >= interval.duration - tolerance
    }
}
