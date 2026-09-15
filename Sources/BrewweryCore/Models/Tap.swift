import Foundation

public struct BrewTap: Identifiable, Hashable, Codable, Sendable {
    public var name: String
    /// `true` when the tap name starts with `homebrew/`.
    public var official: Bool

    public var id: String { name }

    public init(name: String, official: Bool) {
        self.name = name
        self.official = official
    }
}

public enum TapAction: String, Codable, Sendable, Hashable {
    case tap
    case untap
}
