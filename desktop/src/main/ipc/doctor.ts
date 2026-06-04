import { ipcMain } from "electron";
import type { DoctorResult, IpcResponse } from "@brewwery/shared-types";
import { getNativeCore } from "./core";
import { BrewweryIpcError, toIpcResponse } from "./errors";

export function registerDoctorHandlers(): void {
  ipcMain.handle("doctor:run", async (): Promise<IpcResponse<DoctorResult>> => toIpcResponse(runDoctor));
}

async function runDoctor(): Promise<DoctorResult> {
  const core = await getNativeCore();
  assertHomebrew(core.detectHomebrew());

  try {
    return core.runDoctor();
  } catch (error) {
    throw new BrewweryIpcError("DOCTOR_FAILED", "Failed to run brew doctor.", error instanceof Error ? error.message : String(error));
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
