import Foundation

/// Ports the `brew config` handling in `system.rs::get_brew_info`.
public enum BrewConfigParser {
    public static func makeInfo(
        path: String,
        configOutput: String?,
        versionOutput: String?
    ) -> BrewInfo {
        let pairs = configOutput.map(KeyValueParser.parse) ?? []

        let version = KeyValueParser.value(for: "HOMEBREW_VERSION", in: pairs)
            ?? versionOutput?.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init)
            ?? "unknown"

        return BrewInfo(
            version: version,
            prefix: KeyValueParser.value(for: "HOMEBREW_PREFIX", in: pairs) ?? "unknown",
            architecture: architecture(from: pairs),
            path: path
        )
    }

    /// `config_architecture` — Homebrew's reported `macOS` line wins; otherwise fall back to
    /// the architecture Brewwery itself was built for. Neither is hard-coded as the default.
    static func architecture(from pairs: [(key: String, value: String)]) -> BrewArchitecture {
        if let macOS = KeyValueParser.value(for: "macOS", in: pairs) {
            if macOS.contains("arm64") { return .arm64 }
            if macOS.contains("x86_64") { return .x86_64 }
        }

        #if arch(arm64)
        return .arm64
        #elseif arch(x86_64)
        return .x86_64
        #else
        return .unknown
        #endif
    }
}
