import Foundation

/// `ProgressOperationKind` — the five streaming operation families.
public enum OperationKind: String, Codable, Sendable, Hashable, CaseIterable {
    case install
    case uninstall
    case upgrade
    case service
    case cleanup

    /// Fixed safety timeouts from `OPERATION_TIMEOUT_MS`.
    public var timeout: Duration {
        switch self {
        case .install: .seconds(45 * 60)
        case .uninstall: .seconds(15 * 60)
        case .upgrade: .seconds(45 * 60)
        case .service: .seconds(5 * 60)
        case .cleanup: .seconds(30 * 60)
        }
    }

    public var timeoutSeconds: Int {
        switch self {
        case .install, .upgrade: 45 * 60
        case .uninstall: 15 * 60
        case .service: 5 * 60
        case .cleanup: 30 * 60
        }
    }

    /// `formatTimeout()` — used in the cancellation/timeout error message.
    var timeoutDescription: String { "\(timeoutSeconds / 60)-minute" }
}

/// Descriptor handed to the UI when a streaming operation starts (`ProgressOperationStart`).
public struct OperationHandle: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let kind: OperationKind
    /// Human-readable command line, e.g. `brew install --cask iterm2`. Display only.
    public let command: String
    public let target: String?
    public let timeoutSeconds: Int

    public init(id: UUID, kind: OperationKind, command: String, target: String?, timeoutSeconds: Int) {
        self.id = id
        self.kind = kind
        self.command = command
        self.target = target
        self.timeoutSeconds = timeoutSeconds
    }
}

public enum OutputStream: String, Codable, Sendable, Hashable {
    case stdout
    case stderr
}

/// One live chunk or terminal event (`ProgressEvent`).
public enum OperationEvent: Sendable {
    case started(at: Date)
    case output(stream: OutputStream, chunk: String, at: Date)
    case completed(stdout: String, stderr: String, statusCode: Int32?, at: Date)
    case failed(stdout: String, stderr: String, statusCode: Int32?, error: BrewweryError, at: Date)
}

/// Lifecycle of a streaming operation as rendered by `OperationProgressPanel`.
public enum OperationStatus: String, Sendable, Hashable {
    case running
    case success
    case failed
    case cancelled
    case timedOut

    /// `formatStatus()` — "timed out" instead of the raw identifier.
    public var displayName: String { self == .timedOut ? "timed out" : rawValue }
}

public struct OperationLine: Hashable, Sendable, Identifiable {
    public let id = UUID()
    public let stream: OutputStream
    public let text: String
    public let timestamp: Date

    public init(stream: OutputStream, text: String, timestamp: Date) {
        self.stream = stream
        self.text = text
        self.timestamp = timestamp
    }
}
