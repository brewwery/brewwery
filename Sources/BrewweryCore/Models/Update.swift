import Foundation

/// One row of `brew outdated --json=v2`, normalised by `updates.rs::normalize_outdated`.
public struct OutdatedPackage: Identifiable, Hashable, Codable, Sendable {
    public var name: String
    public var kind: PackageKind
    public var installedVersions: [String]
    /// First installed version — the legacy field is confusingly named `currentVersion`.
    public var currentVersion: String?
    /// Homebrew's `current_version`, i.e. the version available upstream.
    public var latestVersion: String?
    public var pinned: Bool?
    public var pinnedVersion: String?

    public var id: String { "\(kind.rawValue):\(name)" }

    public init(
        name: String,
        kind: PackageKind,
        installedVersions: [String],
        currentVersion: String? = nil,
        latestVersion: String? = nil,
        pinned: Bool? = nil,
        pinnedVersion: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.installedVersions = installedVersions
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.pinned = pinned
        self.pinnedVersion = pinnedVersion
    }
}
