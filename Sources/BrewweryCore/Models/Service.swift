import Foundation

/// `ServiceStatus` — the four states `services.rs::normalize_status` collapses Homebrew into.
public enum ServiceStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case started
    case stopped
    case error
    case unknown
}

public struct BrewService: Identifiable, Hashable, Codable, Sendable {
    public var name: String
    public var status: ServiceStatus
    public var user: String?
    public var file: String?
    public var command: String?

    public var id: String { name }

    public init(
        name: String,
        status: ServiceStatus,
        user: String? = nil,
        file: String? = nil,
        command: String? = nil
    ) {
        self.name = name
        self.status = status
        self.user = user
        self.file = file
        self.command = command
    }
}

public enum ServiceAction: String, Codable, Sendable, Hashable, CaseIterable {
    case start
    case stop
    case restart
}
