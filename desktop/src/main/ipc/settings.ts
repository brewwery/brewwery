import { ipcMain } from "electron";
import type { BrewPathValidationResult, IpcResponse } from "@brewwery/shared-types";
import { clearStoredHomebrewPath, getStoredHomebrewPath, setStoredHomebrewPath } from "../settings-storage";
import { getNativeCore } from "./core";
import { toIpcResponse } from "./errors";

export function registerSettingsHandlers(): void {
  ipcMain.handle("settings:getHomebrewPath", async (): Promise<IpcResponse<string | undefined>> =>
    toIpcResponse(() => getStoredHomebrewPath())
  );
  ipcMain.handle(
    "settings:validateHomebrewPath",
    async (_event, path: string): Promise<IpcResponse<BrewPathValidationResult>> =>
      toIpcResponse(() => validateHomebrewPath(path))
  );
  ipcMain.handle(
    "settings:setHomebrewPath",
    async (_event, path: string): Promise<IpcResponse<BrewPathValidationResult>> =>
      toIpcResponse(() => setHomebrewPath(path))
  );
  ipcMain.handle("settings:clearHomebrewPath", async (): Promise<IpcResponse<undefined>> =>
    toIpcResponse(clearHomebrewPath)
  );
}

async function validateHomebrewPath(path: string): Promise<BrewPathValidationResult> {
  const core = await getNativeCore();
  return core.validateBrewPath(path);
}

async function setHomebrewPath(path: string): Promise<BrewPathValidationResult> {
  const core = await getNativeCore();
  const validation = core.setCustomBrewPath(path);
  if (validation.valid) {
    setStoredHomebrewPath(validation.path);
  }
  return validation;
}

async function clearHomebrewPath(): Promise<undefined> {
  const core = await getNativeCore();
  core.clearCustomBrewPath();
  clearStoredHomebrewPath();
  return undefined;
}
