import { ipcMain } from "electron";
import type { BrewUpdateResult, IpcResponse, OutdatedPackage, UpgradeRequest, UpgradeResult } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerUpdateHandlers(): void {
  ipcMain.handle("updates:list", async (): Promise<IpcResponse<OutdatedPackage[]>> => toIpcResponse(listUpdates));
  ipcMain.handle("updates:updateMetadata", async (): Promise<IpcResponse<BrewUpdateResult>> => toIpcResponse(updateMetadata));
  ipcMain.handle(
    "updates:upgradePackage",
    async (_event, request: UpgradeRequest): Promise<IpcResponse<UpgradeResult>> =>
      toIpcResponse(() => upgradePackage(request))
  );
  ipcMain.handle("updates:upgradeAll", async (): Promise<IpcResponse<UpgradeResult>> => toIpcResponse(upgradeAll));
}

async function updateMetadata(): Promise<BrewUpdateResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.updateHomebrewMetadata();
  } catch (error) {
    throw mapUpdateError(error, "metadata");
  }
}

async function listUpdates(): Promise<OutdatedPackage[]> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.listOutdated();
  } catch (error) {
    throw mapUpdateError(error, "list");
  }
}

async function upgradePackage(request: UpgradeRequest): Promise<UpgradeResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.upgradePackage(request);
  } catch (error) {
    throw mapUpdateError(error, "upgrade");
  }
}

async function upgradeAll(): Promise<UpgradeResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.upgradeAll();
  } catch (error) {
    throw mapUpdateError(error, "upgrade");
  }
}

function assertHomebrew(detection: { found: boolean; error?: { message: string; raw?: string } }) {
  if (!detection.found) {
    throw new BrewweryIpcError(
      "HOMEBREW_NOT_FOUND",
      detection.error?.message ?? "Homebrew was not found.",
      detection.error?.raw
    );
  }
}

function mapUpdateError(error: unknown, phase: "list" | "metadata" | "upgrade") {
  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();

  if (lower.includes("invalid package name")) {
    return new BrewweryIpcError("INVALID_PACKAGE_NAME", "The package name is not valid.", message);
  }

  if (lower.includes("parse")) {
    return new BrewweryIpcError("UPDATES_PARSE_FAILED", "Brewwery could not parse Homebrew updates output.", message);
  }

  if (lower.includes("command failed")) {
    return new BrewweryIpcError(
      phase === "metadata" ? "BREW_UPDATE_FAILED" : "BREW_COMMAND_FAILED",
      phase === "metadata" ? "Homebrew metadata update failed." : "Homebrew update command failed.",
      message
    );
  }

  return error;
}
