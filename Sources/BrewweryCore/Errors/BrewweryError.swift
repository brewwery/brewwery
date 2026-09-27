import Foundation

/// The single error type surfaced by `BrewweryCore`.
///
/// It carries the three concerns the legacy app kept separate — a stable machine code, a
/// user-facing message and optional raw developer diagnostics — so the UI can render a calm
/// message with an expandable "Show details" disclosure exactly as 0.9.7 did.
public struct BrewweryError: Error, Hashable, Codable, Sendable {
    public let code: BrewweryErrorCode
    /// Message as produced by the failing layer. `friendlyMessage` is what the UI shows.
    public let message: String
    /// Raw command output / underlying error text. Never rendered without a disclosure.
    public let raw: String?

    public init(code: BrewweryErrorCode, message: String, raw: String? = nil) {
        self.code = code
        self.message = message
        self.raw = raw
    }
}

extension BrewweryError: LocalizedError {
    public var errorDescription: String? { friendlyMessage }
}

public extension BrewweryError {
    /// Calm, user-facing copy. Ported verbatim from `renderer/lib/errors.ts`.
    var friendlyMessage: String {
        Self.friendlyMessages[code] ?? message
    }

    /// Technical detail shown behind the "Show details" disclosure, or `nil` when the
    /// friendly message already says everything. Ported from `errorDetails()`.
    var details: String? {
        if let raw, !raw.isEmpty { return raw }
        return message != friendlyMessage ? message : nil
    }

    /// Looked up at the moment it is shown, so it follows the app's language.
    static var friendlyMessages: [BrewweryErrorCode: String] {
        [
            .homebrewNotFound: String(localized: "Brewwery could not find Homebrew. Install Homebrew or set a custom path in Settings."),
            .brewCommandFailed: String(localized: "Homebrew could not complete this command. Review the details or try again from Terminal."),
            .brewJSONParseFailed: String(localized: "Brewwery could not read Homebrew's JSON output. Updating Homebrew may fix this."),
            .permissionDenied: String(localized: "Brewwery does not have permission to access this path or command."),
            .unsupportedPlatform: String(localized: "Brewwery currently supports macOS only."),
            .serviceCommandFailed: String(localized: "Homebrew could not complete the service action."),
            .updatesParseFailed: String(localized: "Brewwery could not read the outdated package list from Homebrew."),
            .invalidPackageName: String(localized: "This package name contains unsupported characters."),
            .invalidServiceName: String(localized: "This service name contains unsupported characters."),
            .cleanupPreviewFailed: String(localized: "Brewwery could not preview cleanup results."),
            .cleanupRunFailed: String(localized: "Homebrew cleanup did not complete."),
            .doctorFailed: String(localized: "brew doctor did not complete."),
            .brewfileExportFailed: String(localized: "Brewwery could not export the Brewfile."),
            .brewfileReadFailed: String(localized: "Brewwery could not read this Brewfile."),
            .invalidFilePath: String(localized: "This file path is not valid for this operation."),
            .packageSearchFailed: String(localized: "Homebrew search did not complete."),
            .packageInfoFailed: String(localized: "Brewwery could not load package details."),
            .packageInstallFailed: String(localized: "Homebrew could not install this package."),
            .packageUninstallFailed: String(localized: "Homebrew could not uninstall this package."),
            .invalidCaskToken: String(localized: "This cask token contains unsupported characters."),
            .operationCancelled: String(localized: "The Homebrew operation was cancelled."),
            .operationInProgress: String(localized: "Another Homebrew operation is already running. Wait for it to finish or cancel it first."),
            .operationTimeout: String(localized: "The Homebrew operation exceeded its safety timeout and was stopped."),
            .invalidTapName: String(localized: "Tap names must look like owner/repository."),
            .tapCommandFailed: String(localized: "Homebrew could not change this tap."),
            .brewUpdateFailed: String(localized: "Homebrew could not update its package information."),
            .blockedExternalURL: String(localized: "Brewwery only opens links to its own sites, Homebrew and its GitHub repository."),
            .unknownError: String(localized: "Something unexpected happened. The details may help diagnose it.")
        ]
    }
}

// MARK: - Constructors mirroring the legacy error sites

public extension BrewweryError {
    static let homebrewNotFound = BrewweryError(
        code: .homebrewNotFound,
        message: "Homebrew was not found in /opt/homebrew, /usr/local, or PATH."
    )

    static func commandFailed(_ raw: String) -> BrewweryError {
        BrewweryError(code: .brewCommandFailed, message: "command failed: \(raw)", raw: raw.isEmpty ? nil : raw)
    }

    static func parseFailed(_ raw: String) -> BrewweryError {
        BrewweryError(
            code: .brewJSONParseFailed,
            message: "unable to parse Homebrew output: \(raw)",
            raw: raw
        )
    }

    static func invalidPackageName(_ name: String) -> BrewweryError {
        BrewweryError(code: .invalidPackageName, message: "invalid package name: \(name)", raw: name)
    }

    static func invalidCaskToken(_ token: String) -> BrewweryError {
        BrewweryError(code: .invalidCaskToken, message: "invalid cask token: \(token)", raw: token)
    }

    static func invalidServiceName(_ name: String) -> BrewweryError {
        BrewweryError(code: .invalidServiceName, message: "invalid service name: \(name)", raw: name)
    }

    static func invalidTapName(_ name: String) -> BrewweryError {
        BrewweryError(code: .invalidTapName, message: "invalid tap name: \(name)", raw: name)
    }

    static func invalidFilePath(_ path: String) -> BrewweryError {
        BrewweryError(code: .invalidFilePath, message: "invalid file path: \(path)", raw: path)
    }

    static let invalidSearchQuery = BrewweryError(
        code: .invalidPackageName,
        message: "invalid package search query"
    )

    static let operationInProgress = BrewweryError(
        code: .operationInProgress,
        message: "Another Homebrew operation is already running."
    )

    static func unknown(_ error: any Error) -> BrewweryError {
        if let brewweryError = error as? BrewweryError { return brewweryError }
        if error is CancellationError {
            return BrewweryError(code: .operationCancelled, message: "The Homebrew operation was cancelled.")
        }
        let nsError = error as NSError
        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(EACCES) {
            return BrewweryError(
                code: .permissionDenied,
                message: "Brewwery does not have permission to run this Homebrew command.",
                raw: nsError.description
            )
        }
        return BrewweryError(code: .unknownError, message: error.localizedDescription, raw: String(describing: error))
    }
}
