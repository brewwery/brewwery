import type { Cask, Formula } from "./package";
import type { BrewDetectionResult, BrewInfo } from "./system";

export type IpcErrorCode =
  | "HOMEBREW_NOT_FOUND"
  | "BREW_COMMAND_FAILED"
  | "BREW_JSON_PARSE_FAILED"
  | "PERMISSION_DENIED"
  | "UNSUPPORTED_PLATFORM"
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
}

export type IpcChannel =
  | "system:detectHomebrew"
  | "system:getBrewInfo"
  | "packages:listFormulae"
  | "packages:listCasks";
