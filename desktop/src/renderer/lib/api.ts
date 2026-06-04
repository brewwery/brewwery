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
    uninstall: () => unsupported(),
    installWithProgress: () => unsupported(),
    uninstallWithProgress: () => unsupported()
  },
  updates: {
    list: () => unsupported(),
    upgradePackage: () => unsupported(),
    upgradeAll: () => unsupported(),
    upgradePackageWithProgress: () => unsupported(),
    upgradeAllWithProgress: () => unsupported()
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
  },
  progress: {
    onEvent: () => () => undefined
  },
  app: {
    onShortcut: () => () => undefined
  }
};

export const api = window.brewwery ?? browserFallbackApi;
