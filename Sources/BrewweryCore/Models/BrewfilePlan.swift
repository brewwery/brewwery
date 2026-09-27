import Foundation

/// What a Brewfile asks for, compared with what this Mac already has.
///
/// The comparison is done here, in Swift, from Brewwery's own parse of the file and the
/// installed lists it already holds. `brew bundle check` would answer the same question, but
/// a Brewfile is Ruby: running any `brew bundle` subcommand on a file evaluates it, and a
/// Brewfile someone sent you can contain arbitrary code. Brewwery never lets Homebrew read a
/// Brewfile it did not write itself — see `installFileContent`.
public struct BrewfilePlan: Sendable, Equatable {
    public enum ItemKind: String, Sendable, Hashable, CaseIterable {
        case tap
        case brew
        case cask
    }

    public struct Item: Sendable, Hashable, Identifiable {
        public let kind: ItemKind
        public let name: String
        public var id: String { "\(kind.rawValue):\(name)" }

        public init(kind: ItemKind, name: String) {
            self.kind = kind
            self.name = name
        }

        /// The one line Brewwery writes for this item. Options from the original line —
        /// `restart_service:`, `args:`, `link:` — are deliberately not carried over.
        var brewfileLine: String { "\(kind.rawValue) \"\(name)\"" }
    }

    /// Why an entry is listed but not installed by Brewwery.
    public struct Skipped: Sendable, Hashable, Identifiable {
        public enum Reason: String, Sendable, Hashable {
            /// `mas`, `vscode`, `whalebrew` and other entries only `brew bundle` knows.
            case notHandled
            /// The name fails the same validation every other Homebrew command applies.
            case invalidName
            /// Anything else — `if`, `end`, variables. Brewwery never runs it, which also
            /// means conditions around `brew` lines are not honoured.
            case rubyCode
        }

        /// Directives `brew bundle` understands that are not Homebrew packages.
        static let bundleOnlyKeywords: Set<String> = [
            "mas", "vscode", "whalebrew", "go", "cargo", "npm", "uv", "flatpak", "krew", "service"
        ]

        public let entry: BrewfileEntry
        public let reason: Reason
        public var id: String { entry.raw }
    }

    /// Installable, not on this Mac yet, in the order Homebrew needs them: taps first.
    public private(set) var missing: [Item]
    public private(set) var installed: [Item]
    public private(set) var skipped: [Skipped]

    public var isSatisfied: Bool { missing.isEmpty }
    public var checkedCount: Int { missing.count + installed.count }

    public init(missing: [Item] = [], installed: [Item] = [], skipped: [Skipped] = []) {
        self.missing = missing
        self.installed = installed
        self.skipped = skipped
    }

    /// Compares `entries` with what is installed.
    ///
    /// Formulae match on either their short or their tap-qualified name, so
    /// `brew "hashicorp/tap/terraform"` is satisfied by an installed `terraform`, and the
    /// same goes for casks. Duplicate lines count once.
    public static func make(
        entries: [BrewfileEntry],
        installedFormulae: [Formula],
        installedCasks: [Cask],
        installedTaps: [BrewTap]
    ) -> BrewfilePlan {
        let formulae = Set(installedFormulae.flatMap { [$0.name, $0.fullName].compactMap { $0?.lowercased() } })
        let casks = Set(installedCasks.map { $0.token.lowercased() })
        let taps = Set(installedTaps.map { $0.name.lowercased() })

        var plan = BrewfilePlan()
        var seen = Set<String>()

        for entry in entries {
            let kind: ItemKind
            switch entry.kind {
            case .tap: kind = .tap
            case .brew: kind = .brew
            case .cask: kind = .cask
            case .mas, .service, .unknown:
                let keyword = entry.raw.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
                let reason: Skipped.Reason = Skipped.bundleOnlyKeywords.contains(keyword) ? .notHandled : .rubyCode
                plan.skipped.append(Skipped(entry: entry, reason: reason))
                continue
            }

            let name = entry.name
            guard isValid(name, as: kind) else {
                plan.skipped.append(Skipped(entry: entry, reason: .invalidName))
                continue
            }

            let item = Item(kind: kind, name: name)
            guard seen.insert(item.id.lowercased()).inserted else { continue }

            let lowered = name.lowercased()
            let shortName = lowered.split(separator: "/").last.map(String.init) ?? lowered
            let isInstalled = switch kind {
            case .tap: taps.contains(lowered) || taps.contains(canonicalTap(lowered))
            case .brew: formulae.contains(lowered) || formulae.contains(shortName)
            case .cask: casks.contains(lowered) || casks.contains(shortName)
            }

            if isInstalled {
                plan.installed.append(item)
            } else {
                plan.missing.append(item)
            }
        }

        // Taps first, because the formulae and casks after them may come from those taps;
        // within a kind, the Brewfile's own order.
        plan.missing = ItemKind.allCases.flatMap { kind in plan.missing.filter { $0.kind == kind } }
        return plan
    }

    // MARK: - The file Brewwery hands to Homebrew

    /// A Brewfile listing only the missing items, one quoted, validated name per line.
    /// Nothing from the user's file is copied verbatim.
    public var installFileContent: String {
        (["# Written by Brewwery: the missing items from the Brewfile you reviewed."]
            + missing.map(\.brewfileLine))
            .joined(separator: "\n") + "\n"
    }

    /// The directory install files are written to. Only files in here can be installed.
    public static var installDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Brewwery-Bundle", isDirectory: true)
    }

    /// Writes `installFileContent` to a fresh file in `installDirectory`.
    public func writeInstallFile() throws(BrewweryError) -> String {
        let directory = Self.installDirectory
        let url = directory.appendingPathComponent("install-\(UUID().uuidString).brewfile")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try installFileContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw BrewweryError(
                code: .brewfileReadFailed,
                message: "Brewwery could not prepare the install list.",
                raw: error.localizedDescription
            )
        }
        return url.path
    }

    /// Whether `content` is something Brewwery wrote: comments and `tap`/`brew`/`cask` lines
    /// with a single validated, quoted name — nothing Ruby could do anything with.
    ///
    /// `HomebrewCommand.bundleInstall` checks this immediately before running, so a file
    /// swapped in after it was written still never reaches Homebrew.
    public static func isInstallFileContent(_ content: String) -> Bool {
        let pattern = #"^(tap|brew|cask) "([^"\\]+)"$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }

        var itemCount = 0
        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let range = NSRange(line.startIndex..., in: line)
            guard let match = regex.firstMatch(in: line, range: range),
                  let kindRange = Range(match.range(at: 1), in: line),
                  let nameRange = Range(match.range(at: 2), in: line),
                  let kind = ItemKind(rawValue: String(line[kindRange])),
                  isValid(String(line[nameRange]), as: kind)
            else { return false }
            itemCount += 1
        }
        return itemCount > 0
    }

    // MARK: - Validation

    static func isValid(_ name: String, as kind: ItemKind) -> Bool {
        switch kind {
        case .tap:
            return (try? HomebrewIdentifier.validateTapName(name)) != nil
        case .brew:
            return (try? HomebrewIdentifier.validateFormulaName(name)) != nil
        case .cask:
            // Casks may be tap-qualified (`homebrew/cask-fonts/font-inter`), which the
            // formula rule covers; bare tokens use the stricter cask rule.
            return name.contains("/")
                ? (try? HomebrewIdentifier.validateFormulaName(name)) != nil
                : (try? HomebrewIdentifier.validateCaskToken(name)) != nil
        }
    }

    /// `brew tap` lists `user/repo`, while Brewfiles sometimes say `user/homebrew-repo`.
    private static func canonicalTap(_ name: String) -> String {
        let parts = name.split(separator: "/", maxSplits: 1)
        guard parts.count == 2, parts[1].hasPrefix("homebrew-") else { return name }
        return "\(parts[0])/\(parts[1].dropFirst("homebrew-".count))"
    }
}
