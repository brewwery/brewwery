import type { IpcError } from "@brewwery/shared-types";

const friendlyMessages: Partial<Record<IpcError["code"], string>> = {
  HOMEBREW_NOT_FOUND: "Brewwery could not find Homebrew. Install Homebrew or set a custom path in Settings.",
  BREW_COMMAND_FAILED: "Homebrew could not complete this command. Review the details or try again from Terminal.",
  BREW_JSON_PARSE_FAILED: "Brewwery could not read Homebrew's JSON output. Updating Homebrew may fix this.",
  PERMISSION_DENIED: "Brewwery does not have permission to access this path or command.",
  UNSUPPORTED_PLATFORM: "Brewwery currently supports macOS only.",
  SERVICE_COMMAND_FAILED: "Homebrew could not complete the service action.",
  UPDATES_PARSE_FAILED: "Brewwery could not read the outdated package list from Homebrew.",
  INVALID_PACKAGE_NAME: "This package name contains unsupported characters.",
  INVALID_SERVICE_NAME: "This service name contains unsupported characters.",
  CLEANUP_PREVIEW_FAILED: "Brewwery could not preview cleanup results.",
  CLEANUP_RUN_FAILED: "Homebrew cleanup did not complete.",
  DOCTOR_FAILED: "brew doctor did not complete.",
  BREWFILE_EXPORT_FAILED: "Brewwery could not export the Brewfile.",
  BREWFILE_READ_FAILED: "Brewwery could not read this Brewfile.",
  INVALID_FILE_PATH: "This file path is not valid for this operation.",
  PACKAGE_SEARCH_FAILED: "Homebrew search did not complete.",
  PACKAGE_INFO_FAILED: "Brewwery could not load package details.",
  PACKAGE_INSTALL_FAILED: "Homebrew could not install this package.",
  PACKAGE_UNINSTALL_FAILED: "Homebrew could not uninstall this package.",
  INVALID_CASK_TOKEN: "This cask token contains unsupported characters.",
  UNKNOWN_ERROR: "Something unexpected happened. The details may help diagnose it."
};

export function friendlyErrorMessage(error?: IpcError) {
  if (!error) return "Something went wrong.";
  return friendlyMessages[error.code] ?? error.message;
}

export function errorDetails(error?: IpcError) {
  if (!error) return undefined;
  if (error.raw) return error.raw;
  return error.message !== friendlyErrorMessage(error) ? error.message : undefined;
}
