import Foundation

public enum BrewfileEntryKind: String, Codable, Sendable, Hashable, CaseIterable {
    case brew
    case cask
    case tap
    case mas
    case service
    case unknown
}

public struct BrewfileEntry: Identifiable, Hashable, Codable, Sendable {
    public var kind: BrewfileEntryKind
    public var name: String
    public var raw: String

    public var id: String { raw }

    public init(kind: BrewfileEntryKind, name: String, raw: String) {
        self.kind = kind
        self.name = name
        self.raw = raw
    }
}

/// Covers both `BrewfileReadResult` (path always present) and `BrewfileExportResult`
/// (path optional) from the legacy contracts.
public struct BrewfileDocument: Hashable, Codable, Sendable {
    public var path: String?
    public var entries: [BrewfileEntry]
    public var rawContent: String

    public init(path: String?, entries: [BrewfileEntry], rawContent: String) {
        self.path = path
        self.entries = entries
        self.rawContent = rawContent
    }
}
