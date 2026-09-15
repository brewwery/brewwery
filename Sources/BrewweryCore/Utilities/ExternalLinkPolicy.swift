import Foundation

/// Allowlist for external links Brewwery is permitted to open.
///
/// Ported from `main/external-links.ts`. Brewwery deliberately has no "open any URL"
/// capability: only HTTPS URLs whose host matches an entry exactly — and, where given, whose
/// path sits under the allowed prefix — can be handed to the system browser.
///
/// Package homepages come from Homebrew rather than from this list, so they are validated
/// separately by `isSafeHomepage(_:)`.
public enum ExternalLinkPolicy {
    struct AllowedTarget: Sendable {
        /// Exact hostname match. No wildcards.
        let host: String
        /// Optional path prefix the URL must start with.
        let pathPrefix: String?

        init(_ host: String, pathPrefix: String? = nil) {
            self.host = host
            self.pathPrefix = pathPrefix
        }
    }

    static let allowedTargets: [AllowedTarget] = [
        AllowedTarget("www.brewwery.com"),
        AllowedTarget("brewwery.com"),
        AllowedTarget("docs.brewwery.com"),
        AllowedTarget("brew.sh"),
        AllowedTarget("docs.brew.sh"),
        // Only the Brewwery repository on GitHub, not all of github.com.
        AllowedTarget("github.com", pathPrefix: "/brewwery/brewwery")
    ]

    public static func isAllowed(_ rawURL: String) -> Bool {
        guard let url = URL(string: rawURL), let host = url.host() else { return false }
        guard url.scheme == "https" else { return false }

        return allowedTargets.contains { target in
            guard host == target.host else { return false }
            guard let prefix = target.pathPrefix else { return true }
            return url.path() == prefix || url.path().hasPrefix("\(prefix)/")
        }
    }

    /// Homepages reported by Homebrew are opened only when they are well-formed http(s)
    /// URLs with a host, so a malformed or `file:`/`javascript:` value can never be launched.
    public static func isSafeHomepage(_ rawURL: String) -> Bool {
        guard let url = URL(string: rawURL), let scheme = url.scheme?.lowercased() else { return false }
        return (scheme == "https" || scheme == "http") && url.host()?.isEmpty == false
    }
}
