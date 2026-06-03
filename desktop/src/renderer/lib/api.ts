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
    listCasks: () => unsupported()
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
  }
};

export const api = window.brewwery ?? browserFallbackApi;
