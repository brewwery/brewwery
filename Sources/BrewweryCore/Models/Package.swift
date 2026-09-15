import Foundation

/// `PackageKind` in `shared-types/src/package.ts`.
public enum PackageKind: String, Codable, Sendable, Hashable, CaseIterable {
    case formula
    case cask
}

/// An installed formula as normalised by `packages.rs::normalize_formula`.
public struct Formula: Identifiable, Hashable, Codable, Sendable {
    public var name: String
    public var fullName: String?
    public var description: String?
    public var installedVersion: String?
    public var homepage: String?
    public var dependencies: [String]?
    public var installedOnRequest: Bool?

    public var id: String { fullName ?? name }

    public init(
        name: String,
        fullName: String? = nil,
        description: String? = nil,
        installedVersion: String? = nil,
        homepage: String? = nil,
        dependencies: [String]? = nil,
        installedOnRequest: Bool? = nil
    ) {
        self.name = name
        self.fullName = fullName
        self.description = description
        self.installedVersion = installedVersion
        self.homepage = homepage
        self.dependencies = dependencies
        self.installedOnRequest = installedOnRequest
    }
}

/// An installed cask as normalised by `packages.rs::normalize_cask`.
public struct Cask: Identifiable, Hashable, Codable, Sendable {
    public var token: String
    /// Homebrew returns either a string or an array here; both collapse to an array.
    public var name: [String]?
    public var description: String?
    public var installedVersion: String?
    public var homepage: String?

    public var id: String { token }
    /// The label the legacy tables show: first display name, else the token.
    public var displayName: String { name?.first ?? token }

    public init(
        token: String,
        name: [String]? = nil,
        description: String? = nil,
        installedVersion: String? = nil,
        homepage: String? = nil
    ) {
        self.token = token
        self.name = name
        self.description = description
        self.installedVersion = installedVersion
        self.homepage = homepage
    }
}

/// One row of `brew search --formula|--cask` output.
public struct PackageSearchResult: Identifiable, Hashable, Codable, Sendable {
    public var name: String
    public var kind: PackageKind
    /// Filled in by the UI against the installed caches, never by Homebrew itself.
    public var installed: Bool?

    public var id: String { "\(kind.rawValue):\(name)" }

    public init(name: String, kind: PackageKind, installed: Bool? = nil) {
        self.name = name
        self.kind = kind
        self.installed = installed
    }
}

/// Normalised `brew info --json=v2` payload for one package.
public struct PackageInfo: Hashable, Codable, Sendable, Identifiable {
    public var name: String
    public var token: String?
    public var fullName: String?
    public var displayName: [String]?
    public var kind: PackageKind
    public var description: String?
    public var homepage: String?
    public var latestVersion: String?
    public var installedVersion: String?
    public var dependencies: [String]?
    public var dependents: [String]?
    public var caveats: String?
    public var installed: Bool
    public var rawJSON: String?

    public var id: String { "\(kind.rawValue):\(token ?? name)" }

    public init(
        name: String,
        token: String? = nil,
        fullName: String? = nil,
        displayName: [String]? = nil,
        kind: PackageKind,
        description: String? = nil,
        homepage: String? = nil,
        latestVersion: String? = nil,
        installedVersion: String? = nil,
        dependencies: [String]? = nil,
        dependents: [String]? = nil,
        caveats: String? = nil,
        installed: Bool,
        rawJSON: String? = nil
    ) {
        self.name = name
        self.token = token
        self.fullName = fullName
        self.displayName = displayName
        self.kind = kind
        self.description = description
        self.homepage = homepage
        self.latestVersion = latestVersion
        self.installedVersion = installedVersion
        self.dependencies = dependencies
        self.dependents = dependents
        self.caveats = caveats
        self.installed = installed
        self.rawJSON = rawJSON
    }
}

/// `PackageActionRequest` — the (name, kind) pair every mutating package operation takes.
public struct PackageReference: Hashable, Codable, Sendable, Identifiable {
    public var name: String
    public var kind: PackageKind

    public var id: String { "\(kind.rawValue):\(name)" }

    public init(name: String, kind: PackageKind) {
        self.name = name
        self.kind = kind
    }
}

/// A locally saved favourite (`FavoritePackage`).
public struct FavoritePackage: Hashable, Codable, Sendable, Identifiable {
    public var name: String
    public var kind: PackageKind
    public var addedAt: Date

    public var id: String { FavoritePackage.key(name: name, kind: kind) }

    public init(name: String, kind: PackageKind, addedAt: Date = Date()) {
        self.name = name
        self.kind = kind
        self.addedAt = addedAt
    }

    /// `favoriteKey()` from the legacy store: case-insensitive, trimmed, kind-scoped.
    public static func key(name: String, kind: PackageKind) -> String {
        "\(kind.rawValue):\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}
