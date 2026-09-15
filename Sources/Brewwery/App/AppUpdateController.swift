import BrewweryCore
import Sparkle
import SwiftUI

/// Application updates.
///
/// Deliberately separate from everything Homebrew-related: a Brewwery release and a Homebrew
/// package upgrade are unrelated systems, and nothing in `Features/Updates` touches this type.
@MainActor
@Observable
final class AppUpdateController {
    private(set) var status: Status = .idle

    enum Status: Equatable {
        case idle
        case unavailable(String)
    }

    private let settings: SettingsStore
    private let driver: (any AppUpdateDriver)?

    init(settings: SettingsStore, driver: (any AppUpdateDriver)? = SparkleUpdateDriver.makeIfConfigured()) {
        self.settings = settings
        self.driver = driver
        if driver == nil {
            status = .unavailable("Automatic updates are available in signed Brewwery builds.")
        } else {
            applyPreferences()
        }
    }

    var canCheckForUpdates: Bool { driver != nil }

    /// Menu- and Settings-driven check. Sparkle owns the resulting UI.
    func checkForUpdates() {
        guard let driver else { return }
        Log.sparkle.info("User requested an application update check")
        driver.checkForUpdates()
    }

    /// Mirrors the user's preferences into the updater.
    func applyPreferences() {
        driver?.setAutomaticChecks(settings.automaticallyCheckForUpdates)
    }
}

/// The seam between the app and Sparkle, so the app builds and tests without an updater.
@MainActor
protocol AppUpdateDriver: AnyObject {
    func checkForUpdates()
    func setAutomaticChecks(_ enabled: Bool)
}

/// Sparkle-backed updates.
///
/// Only created inside the real, signed application bundle that carries a feed URL and an
/// EdDSA public key. Under `swift run` or in tests the main bundle is not Brewwery's, and
/// starting Sparkle there would just raise a configuration alert.
@MainActor
final class SparkleUpdateDriver: NSObject, AppUpdateDriver, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?

    static func makeIfConfigured(bundle: Bundle = .main) -> SparkleUpdateDriver? {
        guard bundle.bundleIdentifier == AppInfo.bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String != nil,
              let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String, !key.isEmpty
        else {
            Log.sparkle.info("Sparkle not started: not running from a configured Brewwery bundle")
            return nil
        }
        return SparkleUpdateDriver()
    }

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    // MARK: SPUUpdaterDelegate

    /// "Include pre-release versions" subscribes to the appcast's `beta` channel.
    nonisolated func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        UserDefaults.standard.bool(forKey: SettingsStore.Key.showPrereleaseUpdates) ? ["beta"] : []
    }
}
