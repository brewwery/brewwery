import type { BrewweryApi, IpcError, IpcResponse } from "@brewwery/shared-types";

const unsupportedError: IpcError = {
  code: "UNSUPPORTED_PLATFORM",
  message: "Brewwery IPC is available inside the Electron desktop app."
};

function unsupported<T>(): Promise<IpcResponse<T>> {
  return Promise.resolve({
    ok: false,
    error: unsupportedError
  });
}

const browserFallbackApi: BrewweryApi = {
  system: {
    detectHomebrew: () => unsupported(),
    getBrewInfo: () => unsupported()
  },
  settings: {
    getHomebrewPath: () => unsupported(),
    validateHomebrewPath: () => unsupported(),
    setHomebrewPath: () => unsupported(),
    clearHomebrewPath: () => unsupported()
  },
  packages: {
    listFormulae: () => unsupported(),
    listCasks: () => unsupported(),
    search: () => unsupported(),
    info: () => unsupported(),
    install: () => unsupported(),
    uninstall: () => unsupported(),
    installWithProgress: () => unsupported(),
    uninstallWithProgress: () => unsupported()
  },
  updates: {
    list: () => unsupported(),
    updateMetadata: () => unsupported(),
    upgradePackage: () => unsupported(),
    upgradeAll: () => unsupported(),
    upgradePackageWithProgress: () => unsupported(),
    upgradeAllWithProgress: () => unsupported()
  },
  services: {
    list: () => unsupported(),
    start: () => unsupported(),
    stop: () => unsupported(),
    restart: () => unsupported(),
    startWithProgress: () => unsupported(),
    stopWithProgress: () => unsupported(),
    restartWithProgress: () => unsupported()
  },
  cleanup: {
    preview: () => unsupported(),
    run: () => unsupported(),
    runWithProgress: () => unsupported()
  },
  doctor: {
    run: () => unsupported()
  },
  brewfile: {
    export: () => unsupported(),
    read: () => unsupported()
  },
  progress: {
    cancel: () => unsupported(),
    onEvent: () => () => undefined
  },
  app: {
    onShortcut: () => () => undefined
  }
};

export const api = window.brewwery ?? browserFallbackApi;
