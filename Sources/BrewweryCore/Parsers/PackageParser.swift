import Foundation

/// Ports `packages.rs` parsing and normalisation.
public enum PackageParser {

    // MARK: - `brew list --formula --json=v2`

    private struct FormulaPayload: Decodable {
        var formulae: [RawFormula]?
    }

    private struct RawFormula: Decodable {
        var name: String?
        var fullName: String?
        var desc: String?
        var description: String?
        var homepage: String?
        var dependencies: [String]?
        var installed: [InstalledFormula]?
        var installedVersions: [String]?
        var versions: [String]?

        enum CodingKeys: String, CodingKey {
            case name
            case fullName = "full_name"
            case desc
            case description
            case homepage
            case dependencies
            case installed
            case installedVersions = "installed_versions"
            case versions
        }
    }

    private struct InstalledFormula: Decodable {
        var version: String?
        var installedOnRequest: Bool?

        enum CodingKeys: String, CodingKey {
            case version
            case installedOnRequest = "installed_on_request"
        }
    }

    public static func parseFormulae(json: String) throws(BrewweryError) -> [Formula] {
        let payload = try HomebrewJSON.decode(FormulaPayload.self, from: json)
        return (payload.formulae ?? []).map(normalize)
    }

    /// `normalize_formula` — name falls back to `full_name` then `"unknown"`; the installed
    /// version is taken from the first `installed` entry, then `installed_versions`, then
    /// `versions`; an empty dependency array becomes `nil`.
    private static func normalize(_ raw: RawFormula) -> Formula {
        let installed = raw.installed?.first
        let dependencies = raw.dependencies.flatMap { $0.isEmpty ? nil : $0 }

        return Formula(
            name: raw.name ?? raw.fullName ?? "unknown",
            fullName: raw.fullName,
            description: raw.desc ?? raw.description,
            installedVersion: installed?.version
                ?? raw.installedVersions?.first
                ?? raw.versions?.first,
            homepage: raw.homepage,
            dependencies: dependencies,
            installedOnRequest: installed?.installedOnRequest
        )
    }

    // MARK: - `brew list --cask --json=v2`

    private struct CaskPayload: Decodable {
        var casks: [RawCask]?
    }

    private struct RawCask: Decodable {
        var token: String?
        var name: StringOrArray?
        var desc: String?
        var description: String?
        var homepage: String?
        var installed: StringOrArray?
        var version: String?
    }

    public static func parseCasks(json: String) throws(BrewweryError) -> [Cask] {
        let payload = try HomebrewJSON.decode(CaskPayload.self, from: json)
        return (payload.casks ?? []).map(normalize)
    }

    /// `normalize_cask` — the installed version falls back to the cask's `version` field.
    private static func normalize(_ raw: RawCask) -> Cask {
        Cask(
            token: raw.token ?? "unknown",
            name: raw.name?.values,
            description: raw.desc ?? raw.description,
            installedVersion: raw.installed?.first ?? raw.version,
            homepage: raw.homepage
        )
    }

    // MARK: - `brew info --json=v2`

    private struct FormulaInfoPayload: Decodable {
        var formulae: [RawInfoFormula]?
    }

    private struct RawInfoFormula: Decodable {
        var name: String?
        var fullName: String?
        var desc: String?
        var homepage: String?
        var caveats: String?
        var versions: FormulaVersions?
        var dependencies: [String]?
        var installed: [InstalledFormula]?

        enum CodingKeys: String, CodingKey {
            case name
            case fullName = "full_name"
            case desc
            case homepage
            case caveats
            case versions
            case dependencies
            case installed
        }
    }

    private struct FormulaVersions: Decodable {
        var stable: String?
    }

    private struct CaskInfoPayload: Decodable {
        var casks: [RawInfoCask]?
    }

    private struct RawInfoCask: Decodable {
        var token: String?
        var fullToken: String?
        var name: StringOrArray?
        var desc: String?
        var homepage: String?
        var version: String?
        var installed: StringOrArray?
        var caveats: String?
        var dependsOn: [String: DependencyValue]?

        enum CodingKeys: String, CodingKey {
            case token
            case fullToken = "full_token"
            case name
            case desc
            case homepage
            case version
            case installed
            case caveats
            case dependsOn = "depends_on"
        }
    }

    /// `depends_on` values are either a string or an array of strings; anything else is
    /// ignored, matching `extract_cask_dependencies`.
    private enum DependencyValue: Decodable {
        case text(String)
        case list([String])
        case other

        var values: [String] {
            switch self {
            case .text(let value): [value]
            case .list(let values): values
            case .other: []
            }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .text(value)
            } else if let values = try? container.decode([String].self) {
                self = .list(values)
            } else {
                self = .other
            }
        }
    }

    public static func parseFormulaInfo(json: String) throws(BrewweryError) -> PackageInfo {
        let payload = try HomebrewJSON.decode(FormulaInfoPayload.self, from: json)
        guard let formula = payload.formulae?.first else {
            throw BrewweryError(code: .packageInfoFailed, message: "package info not found")
        }
        return normalizeInfo(formula, rawJSON: json)
    }

    /// `normalize_formula_info`.
    private static func normalizeInfo(_ raw: RawInfoFormula, rawJSON: String?) -> PackageInfo {
        let installedVersion = raw.installed?.first?.version
        let dependencies = raw.dependencies.flatMap { $0.isEmpty ? nil : $0 }

        return PackageInfo(
            name: raw.name ?? raw.fullName ?? "unknown",
            token: nil,
            fullName: raw.fullName,
            displayName: nil,
            kind: .formula,
            description: raw.desc,
            homepage: raw.homepage,
            latestVersion: raw.versions?.stable,
            installedVersion: installedVersion,
            dependencies: dependencies,
            dependents: nil,
            caveats: raw.caveats,
            installed: installedVersion != nil,
            rawJSON: rawJSON
        )
    }

    public static func parseCaskInfo(json: String) throws(BrewweryError) -> PackageInfo {
        let payload = try HomebrewJSON.decode(CaskInfoPayload.self, from: json)
        guard let cask = payload.casks?.first else {
            throw BrewweryError(code: .packageInfoFailed, message: "package info not found")
        }
        return normalizeInfo(cask, rawJSON: json)
    }

    /// `normalize_cask_info` — `name` carries the token for both fields, as the legacy
    /// drawer keys its actions off `token ?? name`.
    private static func normalizeInfo(_ raw: RawInfoCask, rawJSON: String?) -> PackageInfo {
        let token = raw.token ?? raw.fullToken ?? "unknown"
        let installedVersion = raw.installed?.first
        let dependencies = raw.dependsOn?
            .sorted { $0.key < $1.key }
            .flatMap(\.value.values)
            .nilIfEmpty

        return PackageInfo(
            name: token,
            token: token,
            fullName: raw.fullToken,
            displayName: raw.name?.values,
            kind: .cask,
            description: raw.desc,
            homepage: raw.homepage,
            latestVersion: raw.version,
            installedVersion: installedVersion,
            dependencies: dependencies,
            dependents: nil,
            caveats: raw.caveats,
            installed: installedVersion != nil,
            rawJSON: rawJSON
        )
    }

    // MARK: - Text output

    /// `parse_search_lines` — skips blank lines and `==>` headers, then splits the rest on
    /// whitespace so Homebrew's multi-column output yields one result per token.
    public static func parseSearchLines(_ output: String, kind: PackageKind) -> [PackageSearchResult] {
        output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(\.trimmed)
            .filter { !$0.isEmpty && !$0.hasPrefix("==>") }
            .flatMap { $0.split(whereSeparator: \.isWhitespace) }
            .map { PackageSearchResult(name: String($0), kind: kind) }
    }

    /// `parse_name_lines` — used for `brew leaves` and `brew uses --installed`.
    public static func parseNameLines(_ output: String) -> [String] {
        output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(\.trimmed)
            .filter { !$0.isEmpty && !$0.hasPrefix("==>") }
    }
}

extension Array {
    var nilIfEmpty: [Element]? { isEmpty ? nil : self }
}
