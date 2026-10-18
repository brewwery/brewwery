import BrewweryCore
import Foundation

/// Explicit, persistent QA profiles let the exact release bundle be tested without
/// replacing the user's Favorites, History or preferences. Normal launches are unchanged.
@MainActor
struct QALaunch {
    let name: String
    var preferencesSuite: String { "com.brewwery.qa.\(name)" }
    var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Brewwery QA", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    static func parse(_ arguments: [String]) throws -> QALaunch? {
        let positions = arguments.indices.filter { arguments[$0] == "--qa-profile" }
        guard let index = positions.first else { return nil }
        guard positions.count == 1, arguments.indices.contains(index + 1) else { throw invalidName }
        let name = arguments[index + 1]
        guard (1...64).contains(name.utf8.count),
              name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9-]*$", options: .regularExpression) != nil
        else { throw invalidName }
        return QALaunch(name: name)
    }

    static var current: QALaunch? { try? parse(CommandLine.arguments) }

    private static var invalidName: NSError {
        NSError(domain: "Brewwery.QA", code: 64, userInfo: [NSLocalizedDescriptionKey:
            "--qa-profile requires one name of 1-64 ASCII letters, digits or hyphens, starting with a letter or digit."])
    }

    func makeEnvironment() -> AppEnvironment {
        guard let defaults = UserDefaults(suiteName: preferencesSuite) else {
            preconditionFailure("Unable to create isolated QA preferences")
        }
        defaults.register(defaults: [SettingsStore.Key.automaticallyCheckForUpdates: false,
                                     SettingsStore.Key.showDockBadge: false])
        return AppEnvironment(settings: SettingsStore(defaults: defaults),
                              history: HistoryStore(directory: directory),
                              favorites: FavoritesStore(directory: directory),
                              updateDriver: nil)
    }
}
