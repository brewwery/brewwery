import Foundation

/// `renderer/lib/constants.ts`.
enum AppInfo {
    static let name = "Brewwery"
    static let tagline = "Homebrew, without the terminal."
    static let bundleIdentifier = "com.brewwery.app"
    static let author = "Made Büro"
    static let copyright = "MIT License. Made by Made Büro."

    /// Read from the bundle when the app is packaged, with the source of truth in
    /// `Sources/Brewwery/Resources/Info.plist`.
    static let version: String = {
        guard Bundle.main.bundleIdentifier == bundleIdentifier,
              let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return fallbackVersion }
        return version
    }()
    /// Used by `swift run` and tests, where the main bundle is not Brewwery's.
    static let fallbackVersion = "1.0.0"
    static let channel = "Stable"

    static let githubURL = "https://github.com/brewwery/brewwery"
    static let websiteURL = "https://www.brewwery.com"
    static let issueURL = "https://github.com/brewwery/brewwery/issues"
    static let releaseNotesURL = "https://github.com/brewwery/brewwery/releases/tag/v1.0.0"
    static let homebrewURL = "https://brew.sh"

    /// Appcast the Sparkle updater subscribes to. Kept next to the other URLs so the
    /// production endpoint is changed in one place.
    static let appcastURL = "https://www.brewwery.com/appcast.xml"
}
