#if DEBUG
import BrewweryCore
import Foundation

/// Launch options for producing marketing and documentation screenshots.
///
/// Debug builds only — none of this exists in a release binary. `Scripts/screenshots.sh`
/// passes these as launch arguments:
///
/// - `-BrewweryDemoHomebrew <path>`: run against the scripted demo Homebrew in
///   `Scripts/demo-brew.sh` instead of the real one;
/// - `-BrewweryDemoPage <page>`: the page to open, e.g. `updates`;
/// - `-BrewweryDemoTheme dark|light`;
/// - `-BrewweryDemoSearch <query>`: a query to show on the Search page.
///
/// A demo launch keeps its settings, history and favourites in memory and a temporary
/// directory, so screenshots never show — or change — the real user's data.
@MainActor
struct DemoLaunch {
    let homebrewPath: String
    let page: Page
    let theme: AppTheme
    let search: String?

    /// Shown instead of the demo script's location, so screenshots read like a normal install.
    static let displayedExecutable = "/opt/homebrew/bin/brew"

    static var current: DemoLaunch? {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: "BrewweryDemoHomebrew"), !path.isEmpty else { return nil }
        return DemoLaunch(
            homebrewPath: path,
            page: defaults.string(forKey: "BrewweryDemoPage").flatMap(Page.init(rawValue:)) ?? .dashboard,
            theme: defaults.string(forKey: "BrewweryDemoTheme").flatMap(AppTheme.init(rawValue:)) ?? .dark,
            search: defaults.string(forKey: "BrewweryDemoSearch")
        )
    }

    func makeEnvironment() -> AppEnvironment {
        let suite = "brewwery-demo-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let settings = SettingsStore(defaults: defaults)
        settings.theme = theme

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(suite, isDirectory: true)

        let environment = AppEnvironment(
            client: HomebrewClient(
                detector: HomebrewDetector(candidatePaths: [homebrewPath], environment: ["PATH": "/nonexistent"])
            ),
            settings: settings,
            history: HistoryStore(directory: directory),
            favorites: FavoritesStore(directory: directory),
            updateDriver: DemoUpdateDriver()
        )
        environment.system.displayedExecutableOverride = Self.displayedExecutable
        environment.state.select(page)
        if let search { environment.state.searchQuery = search }
        return environment
    }
}

/// Stands in for Sparkle so the Settings page looks like the signed release, where update
/// checks are available, without contacting the real feed.
@MainActor
private final class DemoUpdateDriver: AppUpdateDriver {
    func checkForUpdates() {}
    func setAutomaticChecks(_ enabled: Bool) {}
}
#endif
