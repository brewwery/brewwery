import Foundation

/// Ports `updates.rs` parsing.
public enum OutdatedParser {
    private struct OutdatedPayload: Decodable {
        var formulae: [RawOutdatedPackage]?
        var casks: [RawOutdatedPackage]?
    }

    private struct RawOutdatedPackage: Decodable {
        var name: String
        var installedVersions: [String]?
        var currentVersion: String?
        var pinned: Bool?
        var pinnedVersion: String?

        enum CodingKeys: String, CodingKey {
            case name
            case installedVersions = "installed_versions"
            case currentVersion = "current_version"
            case pinned
            case pinnedVersion = "pinned_version"
        }
    }

    /// `parse_outdated_inner` — formulae first, then casks, preserving Homebrew's order
    /// within each group.
    public static func parse(json: String) throws(BrewweryError) -> [OutdatedPackage] {
        let payload = try HomebrewJSON.decode(OutdatedPayload.self, from: json)
        return (payload.formulae ?? []).map { normalize($0, kind: .formula) }
            + (payload.casks ?? []).map { normalize($0, kind: .cask) }
    }

    /// `normalize_outdated` — note the deliberate swap: Homebrew's `current_version` is the
    /// version available upstream, so it lands in `latestVersion`, while `currentVersion`
    /// holds the first installed version.
    private static func normalize(_ raw: RawOutdatedPackage, kind: PackageKind) -> OutdatedPackage {
        let installedVersions = raw.installedVersions ?? []
        return OutdatedPackage(
            name: raw.name,
            kind: kind,
            installedVersions: installedVersions,
            currentVersion: installedVersions.first,
            latestVersion: raw.currentVersion,
            pinned: raw.pinned,
            pinnedVersion: raw.pinnedVersion
        )
    }
}
