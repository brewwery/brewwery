import { ipcMain } from "electron";
import type { BrewTap, IpcResponse, TapActionRequest, TapActionResult } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerTapHandlers(): void {
  ipcMain.handle("taps:list", async (): Promise<IpcResponse<BrewTap[]>> => toIpcResponse(listTaps));
  ipcMain.handle("taps:add", async (_event, request: TapActionRequest): Promise<IpcResponse<TapActionResult>> =>
    toIpcResponse(() => addTap(request))
  );
  ipcMain.handle("taps:remove", async (_event, request: TapActionRequest): Promise<IpcResponse<TapActionResult>> =>
    toIpcResponse(() => removeTap(request))
  );
}

async function listTaps(): Promise<BrewTap[]> {
  const core = await checkedCore();
  return core.listTaps();
}

async function addTap(request: TapActionRequest): Promise<TapActionResult> {
  const core = await checkedCore();
  try {
    return core.addTap(request.name);
  } catch (error) {
    throw mapTapError(error, "add");
  }
}

async function removeTap(request: TapActionRequest): Promise<TapActionResult> {
  const core = await checkedCore();
  try {
    return core.removeTap(request.name);
  } catch (error) {
    throw mapTapError(error, "remove");
  }
}

async function checkedCore() {
  const core = await getNativeCore();
  const detection = core.detectHomebrew();
  if (!detection.found) {
    throw new BrewweryIpcError("HOMEBREW_NOT_FOUND", detection.error?.message ?? "Homebrew was not found.", detection.error?.raw);
  }
  return core;
}

function mapTapError(error: unknown, action: "add" | "remove") {
  const message = error instanceof Error ? error.message : String(error);
  if (message.toLowerCase().includes("invalid tap name")) {
    return new BrewweryIpcError("INVALID_TAP_NAME", "Use a tap name in owner/repository format.", message);
  }
  return new BrewweryIpcError("TAP_COMMAND_FAILED", `Failed to ${action} Homebrew tap.`, message);
}
