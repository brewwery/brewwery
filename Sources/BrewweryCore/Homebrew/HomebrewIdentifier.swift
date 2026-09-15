import Foundation

/// Argument validation, ported character-for-character from the legacy Rust core
/// (`packages.rs`, `updates.rs`, `services.rs`, `taps.rs`) and the Electron streaming
/// validators in `ipc/operation-progress.ts`.
///
/// Nothing reaches `Process` without passing through here. These are pure functions so the
/// rules can be exercised by tests without a Homebrew installation.
public enum HomebrewIdentifier {
    /// `is_package_token_char` — ASCII alphanumerics plus `@ - _ . +`. No slash.
    static func isTokenCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || "@-_.+".contains(character))
    }

    /// `is_formula_identifier_char` — token characters plus `/` for tap-qualified names.
    static func isFormulaCharacter(_ character: Character) -> Bool {
        isTokenCharacter(character) || character == "/"
    }

    static func isTapCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || "-_.".contains(character))
    }

    /// Formula names may be tap-qualified (`mongodb/brew/mongodb-community`) but must not
    /// start or end with `/` nor contain `//`.
    ///
    /// Brewwery additionally rejects `..` path segments. The legacy rule allowed them
    /// because `.` and `/` are both legal characters, so `../../etc/passwd` passed
    /// validation and was handed to Homebrew verbatim. No real formula or tap name contains
    /// a `..` segment, so refusing them costs nothing and removes a traversal-shaped
    /// argument from the command surface.
    ///
    /// - Parameter maxLength: 120 on the install/uninstall paths, 160 on the upgrade path.
    ///   The legacy core used different limits per module; both are preserved.
    public static func validateFormulaName(_ name: String, maxLength: Int = 120) throws(BrewweryError) {
        guard !name.isEmpty,
              name.count <= maxLength,
              !name.hasPrefix("/"),
              !name.hasSuffix("/"),
              !name.contains("//"),
              !name.split(separator: "/", omittingEmptySubsequences: false).contains(".."),
              name.allSatisfy(isFormulaCharacter)
        else { throw .invalidPackageName(name) }
    }

    public static func validateCaskToken(_ token: String, maxLength: Int = 120) throws(BrewweryError) {
        guard !token.isEmpty, token.count <= maxLength, token.allSatisfy(isTokenCharacter) else {
            throw BrewweryError.invalidCaskToken(token)
        }
    }

    /// Dispatches to the formula or cask rule based on the reference's kind.
    public static func validate(_ reference: PackageReference, maxLength: Int = 120) throws(BrewweryError) {
        switch reference.kind {
        case .formula: try validateFormulaName(reference.name, maxLength: maxLength)
        case .cask: try validateCaskToken(reference.name, maxLength: maxLength)
        }
    }

    public static func validateServiceName(_ name: String) throws(BrewweryError) {
        guard !name.isEmpty, name.count <= 120, name.allSatisfy(isTokenCharacter) else {
            throw BrewweryError.invalidServiceName(name)
        }
    }

    /// Tap names are strictly `owner/repository`: exactly one slash, both halves non-empty.
    public static func validateTapName(_ name: String) throws(BrewweryError) {
        let parts = name.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let owner = parts.first, !owner.isEmpty,
              let repository = parts.last, !repository.isEmpty,
              name.count <= 160,
              owner.allSatisfy(isTapCharacter),
              repository.allSatisfy(isTapCharacter)
        else { throw BrewweryError.invalidTapName(name) }
    }

    /// `brew search` queries: trimmed, non-empty, ≤80, ASCII package-name characters only.
    /// Rejects non-Latin input before Homebrew is invoked.
    public static func validateSearchQuery(_ query: String) throws(BrewweryError) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              query.count <= 80,
              query.allSatisfy(isTokenCharacter)
        else { throw BrewweryError.invalidSearchQuery }
    }

    /// Non-throwing mirror used by the search field to gate dispatch, matching
    /// `isValidSearchQuery()` in the renderer.
    public static func isValidSearchQuery(_ query: String) -> Bool {
        (try? validateSearchQuery(query)) != nil
    }

    /// Brewfile read paths: absolute, existing regular file, no NUL byte, and a basename of
    /// `Brewfile` or `*.brewfile` (case-insensitive).
    public static func validateBrewfilePath(_ path: String) throws(BrewweryError) {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent.lowercased()
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        guard path.hasPrefix("/"),
              exists,
              !isDirectory.boolValue,
              !path.contains("\0"),
              fileName == "brewfile" || fileName.hasSuffix(".brewfile")
        else { throw BrewweryError.invalidFilePath(path) }
    }

    /// Upper bound on a Brewfile Brewwery will read into memory.
    public static let maximumBrewfileBytes = 1_000_000
}
