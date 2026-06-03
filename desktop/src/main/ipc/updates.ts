import { ipcMain } from "electron";
import type { IpcResponse, OutdatedPackage, UpgradeRequest, UpgradeResult } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerUpdateHandlers(): void {
  ipcMain.handle("updates:list", async (): Promise<IpcResponse<OutdatedPackage[]>> => toIpcResponse(listUpdates));
  ipcMain.handle(
    "updates:upgradePackage",
    async (_event, request: UpgradeRequest): Promise<IpcResponse<UpgradeResult>> =>
      toIpcResponse(() => upgradePackage(request))
  );
  ipcMain.handle("updates:upgradeAll", async (): Promise<IpcResponse<UpgradeResult>> => toIpcResponse(upgradeAll));
}

async function listUpdates(): Promise<OutdatedPackage[]> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.listOutdated();
  } catch (error) {
    throw mapUpdateError(error);
  }
}

async function upgradePackage(request: UpgradeRequest): Promise<UpgradeResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.upgradePackage(request);
  } catch (error) {
    throw mapUpdateError(error);
  }
}

async function upgradeAll(): Promise<UpgradeResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.upgradeAll();
  } catch (error) {
    throw mapUpdateError(error);
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

function mapUpdateError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();

  if (lower.includes("invalid package name")) {
    return new BrewweryIpcError("INVALID_PACKAGE_NAME", "The package name is not valid.", message);
  }

  if (lower.includes("parse")) {
    return new BrewweryIpcError("UPDATES_PARSE_FAILED", "Brewwery could not parse Homebrew updates output.", message);
  }

  if (lower.includes("command failed")) {
    return new BrewweryIpcError("BREW_COMMAND_FAILED", "Homebrew update command failed.", message);
  }

  return error;
}
