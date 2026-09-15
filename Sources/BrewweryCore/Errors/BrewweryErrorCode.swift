import Foundation

/// Stable error codes shared with the legacy implementation (`IpcErrorCode` in
/// `packages/shared-types/src/ipc.ts`). The raw values are preserved verbatim so that
/// user-facing copy, history entries and QA notes carried over from 0.9.7 stay accurate.
public enum BrewweryErrorCode: String, Codable, Sendable, CaseIterable {
    case homebrewNotFound = "HOMEBREW_NOT_FOUND"
    case brewCommandFailed = "BREW_COMMAND_FAILED"
    case brewJSONParseFailed = "BREW_JSON_PARSE_FAILED"
    case permissionDenied = "PERMISSION_DENIED"
    case unsupportedPlatform = "UNSUPPORTED_PLATFORM"
    case blockedExternalURL = "BLOCKED_EXTERNAL_URL"
    case serviceCommandFailed = "SERVICE_COMMAND_FAILED"
    case updatesParseFailed = "UPDATES_PARSE_FAILED"
    case brewUpdateFailed = "BREW_UPDATE_FAILED"
    case invalidPackageName = "INVALID_PACKAGE_NAME"
    case invalidCaskToken = "INVALID_CASK_TOKEN"
    case invalidTapName = "INVALID_TAP_NAME"
    case tapCommandFailed = "TAP_COMMAND_FAILED"
    case packageSearchFailed = "PACKAGE_SEARCH_FAILED"
    case packageInfoFailed = "PACKAGE_INFO_FAILED"
    case packageInstallFailed = "PACKAGE_INSTALL_FAILED"
    case packageUninstallFailed = "PACKAGE_UNINSTALL_FAILED"
    case invalidServiceName = "INVALID_SERVICE_NAME"
    case cleanupPreviewFailed = "CLEANUP_PREVIEW_FAILED"
    case cleanupRunFailed = "CLEANUP_RUN_FAILED"
    case doctorFailed = "DOCTOR_FAILED"
    case brewfileExportFailed = "BREWFILE_EXPORT_FAILED"
    case brewfileReadFailed = "BREWFILE_READ_FAILED"
    case invalidFilePath = "INVALID_FILE_PATH"
    case operationCancelled = "OPERATION_CANCELLED"
    case operationInProgress = "OPERATION_IN_PROGRESS"
    case operationTimeout = "OPERATION_TIMEOUT"
    case unknownError = "UNKNOWN_ERROR"
}
