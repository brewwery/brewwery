import { ipcMain, shell } from "electron";
import type { BrewDetectionResult, BrewInfo, IpcResponse } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";
import { isAllowedExternalUrl } from "../external-links";

export function registerSystemHandlers(): void {
  ipcMain.handle("system:detectHomebrew", async (): Promise<IpcResponse<BrewDetectionResult>> => toIpcResponse(detectHomebrew));
  ipcMain.handle("system:getBrewInfo", async (): Promise<IpcResponse<BrewInfo>> => toIpcResponse(getBrewInfo));
  ipcMain.handle("system:openExternal", async (_event, url: unknown): Promise<IpcResponse<undefined>> => toIpcResponse(() => openExternal(url)));
}

async function detectHomebrew(): Promise<BrewDetectionResult> {
  assertSupportedPlatform();
  const core = await getNativeCore();
  return core.detectHomebrew();
}

async function openExternal(url: unknown): Promise<undefined> {
  if (typeof url !== "string" || !isAllowedExternalUrl(url)) {
    throw new BrewweryIpcError("BLOCKED_EXTERNAL_URL", "This link is not on the allowed list and was blocked.");
  }
  await shell.openExternal(url);
  return undefined;
}

async function getBrewInfo(): Promise<BrewInfo> {
  assertSupportedPlatform();
  const core = await getNativeCore();
  const detection = core.detectHomebrew();

  if (!detection.found) {
    throw new BrewweryIpcError(
      "HOMEBREW_NOT_FOUND",
      detection.error?.message ?? "Homebrew was not found.",
      detection.error?.raw
    );
  }

  return core.getBrewInfo();
}

function assertSupportedPlatform() {
  if (process.platform !== "darwin") {
    throw new BrewweryIpcError("UNSUPPORTED_PLATFORM", "Brewwery currently supports macOS only.");
  }
}
