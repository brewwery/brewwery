import { ipcMain } from "electron";
import type { CleanupPreview, CleanupResult, IpcResponse } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerCleanupHandlers(): void {
  ipcMain.handle("cleanup:preview", async (): Promise<IpcResponse<CleanupPreview>> => toIpcResponse(previewCleanup));
  ipcMain.handle("cleanup:run", async (): Promise<IpcResponse<CleanupResult>> => toIpcResponse(runCleanup));
}

async function previewCleanup(): Promise<CleanupPreview> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.previewCleanup();
  } catch (error) {
    throw mapCleanupError(error, "preview");
  }
}

async function runCleanup(): Promise<CleanupResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.runCleanup();
  } catch (error) {
    throw mapCleanupError(error, "run");
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

function mapCleanupError(error: unknown, phase: "preview" | "run") {
  const message = error instanceof Error ? error.message : String(error);
  return new BrewweryIpcError(
    phase === "preview" ? "CLEANUP_PREVIEW_FAILED" : "CLEANUP_RUN_FAILED",
    phase === "preview" ? "Failed to preview Homebrew cleanup." : "Cleanup failed.",
    message
  );
}
