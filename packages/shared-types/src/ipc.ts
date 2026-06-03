import type { Cask, Formula } from "./package";
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
  | "services:restart";
