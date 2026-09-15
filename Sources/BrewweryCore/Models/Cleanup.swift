import Foundation

public enum CleanupItemKind: String, Codable, Sendable, Hashable {
    case cache
    case oldVersion = "old_version"
    case download
    case unknown

    /// The legacy table renders `kind.replace("_", " ")`.
    public var displayName: String { rawValue.replacingOccurrences(of: "_", with: " ") }
}

public struct CleanupItem: Identifiable, Hashable, Codable, Sendable {
    public var name: String?
    public var path: String?
    public var size: String?
    public var kind: CleanupItemKind?

    public var id: String { "\(path ?? name ?? "unknown")" }

    public init(name: String? = nil, path: String? = nil, size: String? = nil, kind: CleanupItemKind? = nil) {
        self.name = name
        self.path = path
        self.size = size
        self.kind = kind
    }
}

public struct CleanupPreview: Hashable, Codable, Sendable {
    public var items: [CleanupItem]
    public var totalSize: String?
    public var rawOutput: String?

    public init(items: [CleanupItem], totalSize: String? = nil, rawOutput: String? = nil) {
        self.items = items
        self.totalSize = totalSize
        self.rawOutput = rawOutput
    }
}

public struct CleanupResult: Hashable, Codable, Sendable {
    public var success: Bool
    public var removedItems: Int?
    public var freedSpace: String?
    public var stdout: String?
    public var stderr: String?

    public init(
        success: Bool,
        removedItems: Int? = nil,
        freedSpace: String? = nil,
        stdout: String? = nil,
        stderr: String? = nil
    ) {
        self.success = success
        self.removedItems = removedItems
        self.freedSpace = freedSpace
        self.stdout = stdout
        self.stderr = stderr
    }
}
