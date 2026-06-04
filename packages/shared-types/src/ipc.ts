import type { BrewfileExportResult, BrewfileReadResult } from "./brewfile";
import type { CleanupPreview, CleanupResult } from "./cleanup";
import type { Cask, Formula } from "./package";
import type { DoctorResult } from "./doctor";
import type { BrewService, ServiceActionRequest, ServiceActionResult } from "./service";
import type { BrewDetectionResult, BrewInfo } from "./system";
import type { OutdatedPackage, UpgradeRequest, UpgradeResult } from "./update";

export type IpcErrorCode =
  | "HOMEBREW_NOT_FOUND"
  | "BREW_COMMAND_FAILED"
  | "BREW_JSON_PARSE_FAILED"
  | "PERMISSION_DENIED"
  | "UNSUPPORTED_PLATFORM"
  | "SERVICE_COMMAND_FAILED"
  | "UPDATES_PARSE_FAILED"
  | "INVALID_PACKAGE_NAME"
  | "INVALID_SERVICE_NAME"
  | "CLEANUP_PREVIEW_FAILED"
  | "CLEANUP_RUN_FAILED"
  | "DOCTOR_FAILED"
  | "BREWFILE_EXPORT_FAILED"
  | "BREWFILE_READ_FAILED"
  | "INVALID_FILE_PATH"
  | "UNKNOWN_ERROR";

export interface IpcError {
  code: IpcErrorCode;
  message: string;
  raw?: string;
}

export interface IpcResponse<T> {
  ok: boolean;
  data?: T;
  error?: IpcError;
}

export interface BrewweryApi {
  system: {
    detectHomebrew(): Promise<IpcResponse<BrewDetectionResult>>;
    getBrewInfo(): Promise<IpcResponse<BrewInfo>>;
  };
  packages: {
    listFormulae(): Promise<IpcResponse<Formula[]>>;
    listCasks(): Promise<IpcResponse<Cask[]>>;
  };
  updates: {
    list(): Promise<IpcResponse<OutdatedPackage[]>>;
    upgradePackage(request: UpgradeRequest): Promise<IpcResponse<UpgradeResult>>;
    upgradeAll(): Promise<IpcResponse<UpgradeResult>>;
  };
  services: {
    list(): Promise<IpcResponse<BrewService[]>>;
    start(request: ServiceActionRequest): Promise<IpcResponse<ServiceActionResult>>;
    stop(request: ServiceActionRequest): Promise<IpcResponse<ServiceActionResult>>;
    restart(request: ServiceActionRequest): Promise<IpcResponse<ServiceActionResult>>;
  };
  cleanup: {
    preview(): Promise<IpcResponse<CleanupPreview>>;
    run(): Promise<IpcResponse<CleanupResult>>;
  };
  doctor: {
    run(): Promise<IpcResponse<DoctorResult>>;
  };
  brewfile: {
    export(): Promise<IpcResponse<BrewfileExportResult>>;
    read(path: string): Promise<IpcResponse<BrewfileReadResult>>;
  };
}

export type IpcChannel =
  | "system:detectHomebrew"
  | "system:getBrewInfo"
  | "packages:listFormulae"
  | "packages:listCasks"
  | "updates:list"
  | "updates:upgradePackage"
  | "updates:upgradeAll"
  | "services:list"
  | "services:start"
  | "services:stop"
  | "services:restart"
  | "cleanup:preview"
  | "cleanup:run"
  | "doctor:run"
  | "brewfile:export"
  | "brewfile:read";
