import { app } from "electron";
import { getNativeCore } from "./ipc/core";

const CHECK_INTERVAL_MS = 30 * 60 * 1000;
const INITIAL_CHECK_DELAY_MS = 15 * 1000;
let timer: ReturnType<typeof setInterval> | undefined;
let initialTimer: ReturnType<typeof setTimeout> | undefined;

export function startBackgroundUpdateCheck(): void {
  if (process.platform !== "darwin" || timer) return;

  initialTimer = setTimeout(() => void refreshUpdateBadge(), INITIAL_CHECK_DELAY_MS);
  initialTimer.unref?.();
  timer = setInterval(() => void refreshUpdateBadge(), CHECK_INTERVAL_MS);
  timer.unref?.();
}

export async function refreshUpdateBadge(): Promise<void> {
  if (process.platform !== "darwin") return;

  try {
    const core = await getNativeCore();
    if (!core.detectHomebrew().found) {
      setUpdateBadge(0);
      return;
    }
    setUpdateBadge(core.listOutdated().length);
  } catch {
    // Background checks are best-effort and must never interrupt app startup.
  }
}

export function setUpdateBadge(count: number): void {
  app.dock?.setBadge(count > 0 ? String(count) : "");
}
