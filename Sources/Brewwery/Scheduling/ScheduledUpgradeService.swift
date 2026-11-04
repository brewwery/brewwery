import BrewweryCore
import Foundation
import ServiceManagement

/// Whether macOS will start the scheduled-upgrade agent.
enum ScheduledUpgradeServiceStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    /// Registered, but the user has to allow it under Login Items first.
    case requiresApproval
    /// The bundle does not contain the agent's property list.
    case notFound
}

/// The launchd registration, behind a protocol so tests never touch the user's login items.
@MainActor
protocol ScheduledUpgradeService: AnyObject {
    var status: ScheduledUpgradeServiceStatus { get }
    func register() throws
    func unregister() throws
    func openLoginItemsSettings()
}

/// `SMAppService.agent` over `Contents/Library/LaunchAgents/<label>.plist`.
///
/// launchd starts `Brewwery --scheduled-upgrade` hourly and at login; the agent itself
/// decides whether the user's interval has elapsed, so changing the interval never has to
/// re-register anything.
@MainActor
final class LaunchAgentScheduledUpgradeService: ScheduledUpgradeService {
    static let label = "com.brewwery.app.scheduled-upgrade"
    static let plistName = "\(label).plist"

    private let service = SMAppService.agent(plistName: plistName)

    /// `nil` under `swift run`, in tests and in QA profiles: only the packaged app carries the
    /// agent's property list, and a QA profile must not schedule work against real Homebrew.
    static func makeIfBundled(bundle: Bundle = .main) -> LaunchAgentScheduledUpgradeService? {
        guard QALaunch.current == nil, bundle.bundleURL.pathExtension == "app" else { return nil }
        let plist = bundle.bundleURL.appendingPathComponent("Contents/Library/LaunchAgents/\(plistName)")
        guard FileManager.default.fileExists(atPath: plist.path) else { return nil }
        return LaunchAgentScheduledUpgradeService()
    }

    var status: ScheduledUpgradeServiceStatus {
        switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        case .notRegistered: .notRegistered
        @unknown default: .notRegistered
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
