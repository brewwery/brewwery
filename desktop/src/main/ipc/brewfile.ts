import { ipcMain } from "electron";
import type { BrewfileExportResult, BrewfileReadResult, IpcResponse } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerBrewfileHandlers(): void {
  ipcMain.handle("brewfile:export", async (): Promise<IpcResponse<BrewfileExportResult>> => toIpcResponse(exportBrewfile));
  ipcMain.handle(
    "brewfile:read",
    async (_event, path: string): Promise<IpcResponse<BrewfileReadResult>> => toIpcResponse(() => readBrewfile(path))
  );
}

async function exportBrewfile(): Promise<BrewfileExportResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.exportBrewfile();
  } catch (error) {
    throw mapBrewfileError(error, "export");
  }
}

async function readBrewfile(path: string): Promise<BrewfileReadResult> {
  const core = await getNativeCore();

  try {
    return core.readBrewfile(path);
  } catch (error) {
    throw mapBrewfileError(error, "read");
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

function mapBrewfileError(error: unknown, phase: "export" | "read") {
  const message = error instanceof Error ? error.message : String(error);
  const lower = message.toLowerCase();

  if (lower.includes("invalid file path")) {
    return new BrewweryIpcError("INVALID_FILE_PATH", "The Brewfile path is not valid.", message);
  }

  return new BrewweryIpcError(
    phase === "export" ? "BREWFILE_EXPORT_FAILED" : "BREWFILE_READ_FAILED",
    phase === "export" ? "Failed to export Brewfile." : "Failed to read Brewfile.",
    message
  );
}
