import { ipcMain } from "electron";
import type { BrewService, IpcResponse, ServiceActionRequest, ServiceActionResult } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerServiceHandlers(): void {
  ipcMain.handle("services:list", async (): Promise<IpcResponse<BrewService[]>> => toIpcResponse(listServices));
  ipcMain.handle(
    "services:start",
    async (_event, request: ServiceActionRequest): Promise<IpcResponse<ServiceActionResult>> =>
      toIpcResponse(() => startService(request))
  );
  ipcMain.handle(
    "services:stop",
    async (_event, request: ServiceActionRequest): Promise<IpcResponse<ServiceActionResult>> =>
      toIpcResponse(() => stopService(request))
  );
  ipcMain.handle(
    "services:restart",
    async (_event, request: ServiceActionRequest): Promise<IpcResponse<ServiceActionResult>> =>
      toIpcResponse(() => restartService(request))
  );
}

async function listServices(): Promise<BrewService[]> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.listServices();
  } catch (error) {
    throw mapServiceError(error);
  }
}

async function startService(request: ServiceActionRequest): Promise<ServiceActionResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.startService(request);
  } catch (error) {
    throw mapServiceError(error);
  }
}

async function stopService(request: ServiceActionRequest): Promise<ServiceActionResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.stopService(request);
  } catch (error) {
    throw mapServiceError(error);
  }
}

async function restartService(request: ServiceActionRequest): Promise<ServiceActionResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.restartService(request);
  } catch (error) {
    throw mapServiceError(error);
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

function mapServiceError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();

  if (lower.includes("invalid service name")) {
    return new BrewweryIpcError("INVALID_SERVICE_NAME", "The service name is not valid.", message);
  }

  if (lower.includes("parse")) {
    return new BrewweryIpcError("BREW_JSON_PARSE_FAILED", "Brewwery could not parse Homebrew services output.", message);
  }

  if (lower.includes("command failed")) {
    return new BrewweryIpcError("SERVICE_COMMAND_FAILED", "Homebrew service command failed.", message);
  }

  return error;
}
