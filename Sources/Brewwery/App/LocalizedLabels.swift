import BrewweryCore
import Foundation

/// Display names for Core values. Core's `rawValue`s are stored in history files and matched
/// in tests, so they stay English identifiers; what people read comes from here.
extension HistoryOperationKind {
    var label: LocalizedStringResource {
        switch self {
        case .install: "install"
        case .uninstall: "uninstall"
        case .upgrade: "upgrade"
        case .brewUpdate: "brew update"
        case .service: "service"
        case .cleanup: "cleanup"
        case .doctor: "doctor"
        case .brewfileExport: "Brewfile export"
        case .brewfileInstall: "Brewfile install"
        case .tap: "tap"
        case .pin: "pin"
        }
    }
}

extension HistoryStatus {
    var label: LocalizedStringResource {
        switch self {
        case .success: "success"
        case .failed: "failed"
        case .cancelled: "cancelled"
        }
    }
}

extension OperationStatus {
    var label: LocalizedStringResource {
        switch self {
        case .running: "running"
        case .success: "success"
        case .failed: "failed"
        case .cancelled: "cancelled"
        case .timedOut: "timed out"
        }
    }
}

extension ServiceAction {
    /// Button titles. Whole phrases below, not "verb + name", because word order and
    /// grammar differ between languages.
    var label: LocalizedStringResource {
        switch self {
        case .start: "Start"
        case .stop: "Stop"
        case .restart: "Restart"
        }
    }

    func confirmationTitle(_ service: String) -> LocalizedStringResource {
        switch self {
        case .start: "Start \(service)?"
        case .stop: "Stop \(service)?"
        case .restart: "Restart \(service)?"
        }
    }

    func successTitle(_ service: String) -> LocalizedStringResource {
        switch self {
        case .start: "Started \(service)"
        case .stop: "Stopped \(service)"
        case .restart: "Restarted \(service)"
        }
    }

    func failureTitle(_ service: String, code: BrewweryErrorCode) -> LocalizedStringResource {
        switch (self, code) {
        case (.start, .operationCancelled): "Cancelled starting \(service)"
        case (.stop, .operationCancelled): "Cancelled stopping \(service)"
        case (.restart, .operationCancelled): "Cancelled restarting \(service)"
        case (.start, .operationTimeout): "Starting \(service) timed out"
        case (.stop, .operationTimeout): "Stopping \(service) timed out"
        case (.restart, .operationTimeout): "Restarting \(service) timed out"
        case (.start, _): "Failed to start \(service)"
        case (.stop, _): "Failed to stop \(service)"
        case (.restart, _): "Failed to restart \(service)"
        }
    }
}

extension ServiceStatus {
    var label: LocalizedStringResource {
        switch self {
        case .started: "started"
        case .stopped: "stopped"
        case .error: "error"
        case .unknown: "unknown"
        }
    }
}

extension DoctorSeverity {
    var label: LocalizedStringResource {
        switch self {
        case .info: "info"
        case .warning: "warning"
        case .error: "error"
        }
    }
}

extension CleanupItemKind {
    var label: LocalizedStringResource {
        switch self {
        case .cache: "cache"
        case .oldVersion: "old version"
        case .download: "download"
        case .unknown: "unknown"
        }
    }
}

extension AppTheme {
    var label: LocalizedStringResource {
        switch self {
        case .system: "system"
        case .dark: "dark"
        case .light: "light"
        }
    }
}
