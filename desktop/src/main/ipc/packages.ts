import { ipcMain } from "electron";
import type { Cask, Formula, IpcResponse } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerPackageHandlers(): void {
  ipcMain.handle("packages:listFormulae", async (): Promise<IpcResponse<Formula[]>> => toIpcResponse(listFormulae));
  ipcMain.handle("packages:listCasks", async (): Promise<IpcResponse<Cask[]>> => toIpcResponse(listCasks));
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

function homebrewNotFound(detection: { error?: { message: string; raw?: string } }) {
  return new BrewweryIpcError(
    "HOMEBREW_NOT_FOUND",
    detection.error?.message ?? "Homebrew was not found.",
    detection.error?.raw
  );
}
