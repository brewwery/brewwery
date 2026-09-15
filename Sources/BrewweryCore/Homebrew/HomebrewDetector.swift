import Darwin
import Foundation

/// Locates and validates the `brew` executable.
///
/// Search order, ported from `system.rs::detect_homebrew`:
/// 1. a validated custom path, when one is configured;
/// 2. `/opt/homebrew/bin/brew` (Apple Silicon), then `/usr/local/bin/brew` (Intel);
/// 3. `brew` resolved from `PATH` via `/usr/bin/which`.
///
/// Neither architecture is hard-coded as the only option, and an unusable custom path falls
/// through to the standard locations rather than failing the whole app.
public actor HomebrewDetector {
    /// `BREW_PATHS` — checked in this order.
    public static let standardPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    private var customPath: String?
    /// The fixed locations probed after the custom path. Injectable so an Intel-only layout
    /// or a Mac without Homebrew can be reproduced on any machine.
    private let candidatePaths: [String]
    /// Environment used for the `PATH` lookup and for probing executables.
    private let environment: [String: String]

    public init(
        customPath: String? = nil,
        candidatePaths: [String] = HomebrewDetector.standardPaths,
        environment: [String: String] = HomebrewEnvironment.values()
    ) {
        self.customPath = customPath.flatMap { $0.isEmpty ? nil : $0 }
        self.candidatePaths = candidatePaths
        self.environment = environment
    }

    public func currentCustomPath() -> String? { customPath }

    /// Applies a custom path after validating it. An invalid path is not stored.
    @discardableResult
    public func setCustomPath(_ path: String) -> BrewPathValidationResult {
        let validation = Self.validate(path: path)
        if validation.valid {
            customPath = validation.path
            Log.homebrew.info("Custom Homebrew path applied")
        }
        return validation
    }

    public func clearCustomPath() {
        customPath = nil
    }

    /// Applies a stored path at launch, dropping it if it no longer validates — mirroring
    /// `applyStoredHomebrewPath()` in the legacy main process.
    @discardableResult
    public func applyStoredCustomPath(_ path: String?) -> BrewPathValidationResult? {
        guard let path, !path.isEmpty else {
            clearCustomPath()
            return nil
        }
        let validation = setCustomPath(path)
        if !validation.valid { clearCustomPath() }
        return validation
    }

    public func detect() -> BrewDetectionResult {
        let checkedPaths = checkedPaths()
        let path = validatedCustomPath() ?? firstExistingCandidate() ?? pathFromWhich()
        let found = path != nil

        return BrewDetectionResult(
            found: found,
            path: path,
            checkedPaths: checkedPaths,
            error: found ? nil : .homebrewNotFound
        )
    }

    /// The executable to run, or a `HOMEBREW_NOT_FOUND` error.
    public func executableURL() throws(BrewweryError) -> URL {
        guard let path = detect().path else { throw .homebrewNotFound }
        return URL(fileURLWithPath: path)
    }

    // MARK: - Internals

    private func validatedCustomPath() -> String? {
        guard let customPath else { return nil }
        return Self.validate(path: customPath).valid ? customPath : nil
    }

    /// `checked_paths()` — the custom path is prepended when it is not already a standard
    /// location, and the literal `"PATH"` marks the final fallback.
    private func checkedPaths() -> [String] {
        var paths = candidatePaths
        if let customPath, !paths.contains(customPath) {
            paths.insert(customPath, at: 0)
        }
        paths.append("PATH")
        return paths
    }

    private func firstExistingCandidate() -> String? {
        candidatePaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func pathFromWhich() -> String? {
        guard let output = try? ProcessOutput.capture(
            executablePath: "/usr/bin/which",
            arguments: ["brew"],
            environment: environment
        ), output.success else { return nil }
        let path = output.stdout
        return path.isEmpty ? nil : path
    }

    /// `validate_brew_path_internal` — absolute, existing, a regular file, executable, and
    /// able to answer `brew --version`.
    public nonisolated static func validate(path: String) -> BrewPathValidationResult {
        let normalized = path.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty, normalized.hasPrefix("/") else {
            return invalid(normalized, .invalidFilePath, "Homebrew path must be an absolute path.")
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: normalized, isDirectory: &isDirectory) else {
            return invalid(normalized, .invalidFilePath, "Homebrew executable does not exist.")
        }
        guard !isDirectory.boolValue else {
            return invalid(normalized, .invalidFilePath, "Homebrew path must point to an executable file.")
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: normalized)
            let permissions = (attributes[.posixPermissions] as? NSNumber)?.int16Value ?? 0
            guard permissions & 0o111 != 0 else {
                return invalid(normalized, .permissionDenied, "Homebrew path is not executable.")
            }
        } catch {
            return invalid(normalized, .permissionDenied, error.localizedDescription)
        }

        do {
            let output = try ProcessOutput.capture(
                executablePath: normalized,
                arguments: ["--version"],
                environment: HomebrewEnvironment.values()
            )
            guard output.success else {
                return invalid(normalized, .brewCommandFailed, output.stderr)
            }
            return BrewPathValidationResult(
                valid: true,
                path: normalized,
                version: output.stdout.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init)
            )
        } catch {
            return invalid(normalized, .brewCommandFailed, error.localizedDescription)
        }
    }

    private static func invalid(
        _ path: String,
        _ code: BrewweryErrorCode,
        _ message: String
    ) -> BrewPathValidationResult {
        BrewPathValidationResult(
            valid: false,
            path: path,
            version: nil,
            error: BrewweryError(code: code, message: message)
        )
    }
}
