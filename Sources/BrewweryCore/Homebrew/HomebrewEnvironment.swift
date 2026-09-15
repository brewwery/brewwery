import Foundation

/// The environment Homebrew is invoked with.
///
/// Brewwery inherits the user's environment and overrides exactly the two variables the
/// legacy implementation set — no more. Adding others would silently change Homebrew's
/// behaviour relative to 0.9.7.
public enum HomebrewEnvironment {
    /// Suppresses the implicit `brew update` Homebrew would otherwise run before installs,
    /// so metadata refresh stays an explicit, confirmed user action.
    public static let noAutoUpdateKey = "HOMEBREW_NO_AUTO_UPDATE"
    /// Brewwery sends no telemetry of its own and disables Homebrew's.
    public static let noAnalyticsKey = "HOMEBREW_NO_ANALYTICS"

    public static func values(
        inheriting parent: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var environment = parent
        environment[noAutoUpdateKey] = "1"
        environment[noAnalyticsKey] = "1"
        return environment
    }
}
