import type { BrewfileExportResult, BrewfileReadResult } from "./brewfile";
import type { CleanupPreview, CleanupResult } from "./cleanup";
import type { Cask, Formula, PackageActionRequest, PackageActionResult, PackageInfo, PackageSearchResult } from "./package";
import type { DoctorResult } from "./doctor";
import type { BrewService, ServiceActionRequest, ServiceActionResult } from "./service";
import type { BrewDetectionResult, BrewInfo, BrewPathValidationResult } from "./system";
import type { BrewUpdateResult, OutdatedPackage, UpgradeRequest, UpgradeResult } from "./update";

export type ProgressOperationKind = "install" | "uninstall" | "upgrade";
export type ProgressEventType = "started" | "stdout" | "stderr" | "completed" | "failed";
export type AppShortcut = "search" | "refresh" | "settings" | "updates" | "doctor";

export interface ProgressOperationStart {
  operationId: string;
  kind: ProgressOperationKind;
  command: string;
  target?: string;
}

export interface ProgressEvent {
  operationId: string;
  kind: ProgressOperationKind;
  type: ProgressEventType;
  command: string;
  timestamp: string;
  target?: string;
  chunk?: string;
  stdout?: string;
  stderr?: string;
  statusCode?: number;
  result?: PackageActionResult | UpgradeResult;
  error?: IpcError;
}

export type IpcErrorCode =
  | "HOMEBREW_NOT_FOUND"
  | "BREW_COMMAND_FAILED"
  | "BREW_JSON_PARSE_FAILED"
  | "PERMISSION_DENIED"
  | "UNSUPPORTED_PLATFORM"
  | "SERVICE_COMMAND_FAILED"
  | "UPDATES_PARSE_FAILED"
  | "BREW_UPDATE_FAILED"
  | "INVALID_PACKAGE_NAME"
  | "INVALID_CASK_TOKEN"
  | "PACKAGE_SEARCH_FAILED"
  | "PACKAGE_INFO_FAILED"
  | "PACKAGE_INSTALL_FAILED"
  | "PACKAGE_UNINSTALL_FAILED"
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
  settings: {
    getHomebrewPath(): Promise<IpcResponse<string | undefined>>;
    validateHomebrewPath(path: string): Promise<IpcResponse<BrewPathValidationResult>>;
    setHomebrewPath(path: string): Promise<IpcResponse<BrewPathValidationResult>>;
    clearHomebrewPath(): Promise<IpcResponse<undefined>>;
  };
  packages: {
    listFormulae(): Promise<IpcResponse<Formula[]>>;
    listCasks(): Promise<IpcResponse<Cask[]>>;
    search(query: string): Promise<IpcResponse<PackageSearchResult[]>>;
    info(request: PackageActionRequest): Promise<IpcResponse<PackageInfo>>;
    install(request: PackageActionRequest): Promise<IpcResponse<PackageActionResult>>;
    uninstall(request: PackageActionRequest): Promise<IpcResponse<PackageActionResult>>;
    installWithProgress(request: PackageActionRequest): Promise<IpcResponse<ProgressOperationStart>>;
    uninstallWithProgress(request: PackageActionRequest): Promise<IpcResponse<ProgressOperationStart>>;
  };
  updates: {
    list(): Promise<IpcResponse<OutdatedPackage[]>>;
    updateMetadata(): Promise<IpcResponse<BrewUpdateResult>>;
    upgradePackage(request: UpgradeRequest): Promise<IpcResponse<UpgradeResult>>;
    upgradeAll(): Promise<IpcResponse<UpgradeResult>>;
    upgradePackageWithProgress(request: UpgradeRequest): Promise<IpcResponse<ProgressOperationStart>>;
    upgradeAllWithProgress(): Promise<IpcResponse<ProgressOperationStart>>;
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
  progress: {
    onEvent(callback: (event: ProgressEvent) => void): () => void;
  };
  app: {
    onShortcut(callback: (shortcut: AppShortcut) => void): () => void;
  };
}

export type IpcChannel =
  | "system:detectHomebrew"
  | "system:getBrewInfo"
  | "settings:getHomebrewPath"
  | "settings:validateHomebrewPath"
  | "settings:setHomebrewPath"
  | "settings:clearHomebrewPath"
  | "packages:listFormulae"
  | "packages:listCasks"
  | "packages:search"
  | "packages:info"
  | "packages:install"
  | "packages:uninstall"
  | "packages:installProgress"
  | "packages:uninstallProgress"
  | "updates:list"
  | "updates:updateMetadata"
  | "updates:upgradePackage"
  | "updates:upgradeAll"
  | "updates:upgradePackageProgress"
  | "updates:upgradeAllProgress"
  | "services:list"
  | "services:start"
  | "services:stop"
  | "services:restart"
  | "cleanup:preview"
  | "cleanup:run"
  | "doctor:run"
  | "brewfile:export"
  | "brewfile:read";
