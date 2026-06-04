import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { app } from "electron";

interface StoredSettings {
  homebrewPath?: string;
}

const settingsFileName = "settings.json";

export function getStoredHomebrewPath(): string | undefined {
  return readSettings().homebrewPath;
}

export function setStoredHomebrewPath(path: string): void {
  writeSettings({ ...readSettings(), homebrewPath: path });
}

export function clearStoredHomebrewPath(): void {
  const { homebrewPath: _homebrewPath, ...settings } = readSettings();
  writeSettings(settings);
}

function readSettings(): StoredSettings {
  const filePath = settingsFilePath();
  if (!existsSync(filePath)) return {};

  try {
    return JSON.parse(readFileSync(filePath, "utf8")) as StoredSettings;
  } catch {
    return {};
  }
}

function writeSettings(settings: StoredSettings): void {
  const filePath = settingsFilePath();
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, `${JSON.stringify(settings, null, 2)}\n`, "utf8");
}

function settingsFilePath() {
  return join(app.getPath("userData"), settingsFileName);
}
