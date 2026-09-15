import Foundation

/// Ports `services.rs` parsing.
public enum ServiceParser {
    private struct RawService: Decodable {
        var name: String
        var status: String?
        var user: String?
        var file: String?
        var command: String?
    }

    public static func parse(json: String) throws(BrewweryError) -> [BrewService] {
        let raw = try HomebrewJSON.decode([RawService].self, from: json)
        return raw.map {
            BrewService(
                name: $0.name,
                status: normalizeStatus($0.status),
                user: $0.user,
                file: $0.file,
                command: $0.command
            )
        }
    }

    /// `normalize_status` — Homebrew's `none` is a stopped service; anything Brewwery does
    /// not recognise (for example `scheduled`) becomes `unknown` rather than being guessed.
    public static func normalizeStatus(_ status: String?) -> ServiceStatus {
        switch (status ?? "").lowercased() {
        case "started": .started
        case "stopped", "none": .stopped
        case "error": .error
        default: .unknown
        }
    }
}
