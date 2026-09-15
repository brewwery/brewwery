import Foundation

/// The complete, closed set of Homebrew invocations Brewwery can make.
///
/// UI code cannot construct an argument vector: it names an operation, and this type decides
/// the argv. There is no case that accepts free-form arguments and no shell is involved
/// anywhere — `Process` is given an executable URL and an array.
public enum HomebrewCommand: Hashable, Sendable {
    // Reads
    case version
    case config
    case listFormulae
    case listFormulaeFallback
    case listCasks
    case listCasksFallback
    case leaves
    case dependents(formula: String)
    case searchFormulae(query: String)
    case searchCasks(query: String)
    case formulaInfo(name: String)
    case caskInfo(token: String)
    case outdated
    case listTaps
    case listServices
    case cleanupPreview
    case doctor
    case brewfileDump(path: String)

    // Mutations
    case update
    case install(PackageReference)
    case uninstall(PackageReference)
    case upgrade(PackageReference)
    case upgradeAll
    case addTap(name: String)
    case removeTap(name: String)
    case service(action: ServiceAction, name: String)
    case cleanup

    /// Validates the embedded arguments and returns the argv Homebrew is given.
    ///
    /// Every dynamic component is checked here, so a command value that fails validation can
    /// never be executed.
    public func arguments() throws(BrewweryError) -> [String] {
        switch self {
        case .version:
            return ["--version"]
        case .config:
            return ["config"]
        case .listFormulae:
            return ["list", "--formula", "--json=v2"]
        case .listFormulaeFallback:
            return ["list", "--formula", "--versions", "--json"]
        case .listCasks:
            return ["list", "--cask", "--json=v2"]
        case .listCasksFallback:
            return ["list", "--cask", "--versions", "--json"]
        case .leaves:
            return ["leaves"]
        case .dependents(let formula):
            try HomebrewIdentifier.validateFormulaName(formula)
            return ["uses", "--installed", formula]
        case .searchFormulae(let query):
            try HomebrewIdentifier.validateSearchQuery(query)
            return ["search", "--formula", query]
        case .searchCasks(let query):
            try HomebrewIdentifier.validateSearchQuery(query)
            return ["search", "--cask", query]
        case .formulaInfo(let name):
            try HomebrewIdentifier.validateFormulaName(name)
            return ["info", "--json=v2", name]
        case .caskInfo(let token):
            try HomebrewIdentifier.validateCaskToken(token)
            return ["info", "--cask", "--json=v2", token]
        case .outdated:
            return ["outdated", "--json=v2"]
        case .listTaps:
            return ["tap"]
        case .listServices:
            return ["services", "list", "--json"]
        case .cleanupPreview:
            return ["cleanup", "-n"]
        case .doctor:
            return ["doctor"]
        case .brewfileDump(let path):
            guard path.hasPrefix("/"), !path.contains("\0") else {
                throw BrewweryError.invalidFilePath(path)
            }
            return ["bundle", "dump", "--force", "--file=\(path)"]
        case .update:
            return ["update"]
        case .install(let reference):
            try HomebrewIdentifier.validate(reference)
            return reference.kind == .cask ? ["install", "--cask", reference.name] : ["install", reference.name]
        case .uninstall(let reference):
            try HomebrewIdentifier.validate(reference)
            return reference.kind == .cask ? ["uninstall", "--cask", reference.name] : ["uninstall", reference.name]
        case .upgrade(let reference):
            // The legacy upgrade path allows longer identifiers than install/uninstall.
            try HomebrewIdentifier.validate(reference, maxLength: 160)
            return reference.kind == .cask ? ["upgrade", "--cask", reference.name] : ["upgrade", reference.name]
        case .upgradeAll:
            return ["upgrade"]
        case .addTap(let name):
            try HomebrewIdentifier.validateTapName(name)
            return ["tap", name]
        case .removeTap(let name):
            try HomebrewIdentifier.validateTapName(name)
            return ["untap", name]
        case .service(let action, let name):
            try HomebrewIdentifier.validateServiceName(name)
            return ["services", action.rawValue, name]
        case .cleanup:
            return ["cleanup"]
        }
    }

    /// Display-only rendering, e.g. `brew install --cask iterm2`. Never executed.
    public func displayCommand() -> String {
        guard let arguments = try? arguments() else { return "brew" }
        return (["brew"] + arguments).joined(separator: " ")
    }

    /// `brew doctor` exits non-zero when it reports warnings, so its output must be accepted
    /// regardless of status. Matches `run_brew_output_permissive` usage in `doctor.rs`.
    public var toleratesNonZeroExit: Bool { self == .doctor }
}
