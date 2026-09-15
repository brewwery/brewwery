import Foundation

/// The operations the history log records (`OperationKind` in `history-store.ts` — a wider
/// set than the streaming `OperationKind`, since reads such as doctor are logged too).
public enum HistoryOperationKind: String, Codable, Sendable, Hashable, CaseIterable {
    case install
    case uninstall
    case upgrade
    case brewUpdate = "brew_update"
    case service
    case cleanup
    case doctor
    case brewfileExport = "brewfile_export"
    case tap

    /// The History page renders `kind.replace("_", " ")`.
    public var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ") }
}

public enum HistoryStatus: String, Codable, Sendable, Hashable {
    case success
    case failed
    case cancelled
}

public struct HistoryEntry: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var kind: HistoryOperationKind
    public var status: HistoryStatus
    public var title: String
    public var command: String?
    public var target: String?
    public var timestamp: Date
    public var stdout: String?
    public var stderr: String?
    public var details: String?
    public var error: BrewweryError?

    public init(
        id: UUID = UUID(),
        kind: HistoryOperationKind,
        status: HistoryStatus,
        title: String,
        command: String? = nil,
        target: String? = nil,
        timestamp: Date = Date(),
        stdout: String? = nil,
        stderr: String? = nil,
        details: String? = nil,
        error: BrewweryError? = nil
    ) {
        self.id = id
        self.kind = kind
        self.status = status
        self.title = title
        self.command = command
        self.target = target
        self.timestamp = timestamp
        self.stdout = stdout
        self.stderr = stderr
        self.details = details
        self.error = error
    }

    /// Concatenated output shown behind "Show output details" and copied by the Copy button.
    public var combinedOutput: String {
        [details, stdout, stderr, error?.raw]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}
