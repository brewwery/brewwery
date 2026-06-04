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
  packages: {
    listFormulae: () => unsupported(),
    listCasks: () => unsupported(),
    search: () => unsupported(),
    info: () => unsupported(),
    install: () => unsupported(),
    uninstall: () => unsupported()
  },
  updates: {
    list: () => unsupported(),
    upgradePackage: () => unsupported(),
    upgradeAll: () => unsupported()
  },
  services: {
    list: () => unsupported(),
    start: () => unsupported(),
    stop: () => unsupported(),
    restart: () => unsupported()
  },
  cleanup: {
    preview: () => unsupported(),
    run: () => unsupported()
  },
  doctor: {
    run: () => unsupported()
  },
  brewfile: {
    export: () => unsupported(),
    read: () => unsupported()
  }
};

export const api = window.brewwery ?? browserFallbackApi;
