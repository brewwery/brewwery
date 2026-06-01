import type { IpcError } from "./ipc";

export type BrewArchitecture = "arm64" | "x86_64" | "unknown";

export interface BrewDetectionResult {
  found: boolean;
  path?: string;
  checkedPaths: string[];
  error?: IpcError;
}

export interface BrewInfo {
  version: string;
  prefix: string;
  architecture: BrewArchitecture;
  path: string;
}
