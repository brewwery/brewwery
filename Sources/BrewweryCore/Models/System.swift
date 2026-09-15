import Foundation

public enum BrewArchitecture: String, Codable, Sendable, Hashable {
    case arm64
    case x86_64
    case unknown
}

/// Result of `system.rs::detect_homebrew`.
public struct BrewDetectionResult: Hashable, Codable, Sendable {
    public var found: Bool
    public var path: String?
    /// The paths Brewwery considered, in order, ending with the literal `"PATH"`.
    public var checkedPaths: [String]
    public var error: BrewweryError?

    public init(found: Bool, path: String?, checkedPaths: [String], error: BrewweryError? = nil) {
        self.found = found
        self.path = path
        self.checkedPaths = checkedPaths
        self.error = error
    }
}

/// Result of `system.rs::get_brew_info`.
public struct BrewInfo: Hashable, Codable, Sendable {
    public var version: String
    public var prefix: String
    public var architecture: BrewArchitecture
    public var path: String

    public init(version: String, prefix: String, architecture: BrewArchitecture, path: String) {
        self.version = version
        self.prefix = prefix
        self.architecture = architecture
        self.path = path
    }
}

/// Result of `system.rs::validate_brew_path`.
public struct BrewPathValidationResult: Hashable, Codable, Sendable {
    public var valid: Bool
    public var path: String
    public var version: String?
    public var error: BrewweryError?

    public init(valid: Bool, path: String, version: String? = nil, error: BrewweryError? = nil) {
        self.valid = valid
        self.path = path
        self.version = version
        self.error = error
    }
}
