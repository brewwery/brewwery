import { ipcMain } from "electron";
import type {
  Cask,
  Formula,
  IpcResponse,
  PackageActionRequest,
  PackageActionResult,
  PackageInfo,
  PackageSearchResult
} from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerPackageHandlers(): void {
  ipcMain.handle("packages:listFormulae", async (): Promise<IpcResponse<Formula[]>> => toIpcResponse(listFormulae));
  ipcMain.handle("packages:listCasks", async (): Promise<IpcResponse<Cask[]>> => toIpcResponse(listCasks));
  ipcMain.handle("packages:search", async (_event, query: string): Promise<IpcResponse<PackageSearchResult[]>> =>
    toIpcResponse(() => searchPackages(query))
  );
  ipcMain.handle("packages:info", async (_event, request: PackageActionRequest): Promise<IpcResponse<PackageInfo>> =>
    toIpcResponse(() => getPackageInfo(request))
  );
  ipcMain.handle("packages:install", async (_event, request: PackageActionRequest): Promise<IpcResponse<PackageActionResult>> =>
    toIpcResponse(() => installPackage(request))
  );
  ipcMain.handle("packages:uninstall", async (_event, request: PackageActionRequest): Promise<IpcResponse<PackageActionResult>> =>
    toIpcResponse(() => uninstallPackage(request))
  );
}

async function listFormulae(): Promise<Formula[]> {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found) {
    throw homebrewNotFound(detection);
  }

  return core.listFormulae();
}

async function listCasks(): Promise<Cask[]> {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found) {
    throw homebrewNotFound(detection);
  }

  return core.listCasks();
}

async function searchPackages(query: string): Promise<PackageSearchResult[]> {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found) {
    throw homebrewNotFound(detection);
  }

  try {
    return core.searchPackages(query);
  } catch (error) {
    throw mapPackageError(error, "search");
  }
}

async function getPackageInfo(request: PackageActionRequest): Promise<PackageInfo> {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found) {
    throw homebrewNotFound(detection);
  }

  try {
    return core.getPackageInfo(request);
  } catch (error) {
    throw mapPackageError(error, "info");
  }
}

async function installPackage(request: PackageActionRequest): Promise<PackageActionResult> {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found) {
    throw homebrewNotFound(detection);
  }

  try {
    return request.kind === "cask" ? core.installCask(request.name) : core.installFormula(request.name);
  } catch (error) {
    throw mapPackageError(error, "install");
  }
}

async function uninstallPackage(request: PackageActionRequest): Promise<PackageActionResult> {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found) {
    throw homebrewNotFound(detection);
  }

  try {
    return request.kind === "cask" ? core.uninstallCask(request.name) : core.uninstallFormula(request.name);
  } catch (error) {
    throw mapPackageError(error, "uninstall");
  }
}

function homebrewNotFound(detection: { error?: { message: string; raw?: string } }) {
  return new BrewweryIpcError(
    "HOMEBREW_NOT_FOUND",
    detection.error?.message ?? "Homebrew was not found.",
    detection.error?.raw
  );
}

function mapPackageError(error: unknown, phase: "search" | "info" | "install" | "uninstall") {
  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();

  if (lower.includes("invalid cask token")) {
    return new BrewweryIpcError("INVALID_CASK_TOKEN", "The cask token is not valid.", message);
  }

  if (lower.includes("invalid package name") || lower.includes("invalid package search query")) {
    return new BrewweryIpcError("INVALID_PACKAGE_NAME", "The package name or search query is not valid.", message);
  }

  if (lower.includes("parse")) {
    return new BrewweryIpcError("BREW_JSON_PARSE_FAILED", "Brewwery could not parse Homebrew package output.", message);
  }

  const code =
    phase === "search"
      ? "PACKAGE_SEARCH_FAILED"
      : phase === "info"
        ? "PACKAGE_INFO_FAILED"
        : phase === "install"
          ? "PACKAGE_INSTALL_FAILED"
          : "PACKAGE_UNINSTALL_FAILED";
  return new BrewweryIpcError(code, `Package ${phase} failed.`, message);
}
