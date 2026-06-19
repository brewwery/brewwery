import { contextBridge, ipcRenderer } from "electron";
import type { AppShortcut, BrewweryApi, ProgressEvent } from "@brewwery/shared-types";

const api: BrewweryApi = {
  system: {
    detectHomebrew: () => ipcRenderer.invoke("system:detectHomebrew"),
    getBrewInfo: () => ipcRenderer.invoke("system:getBrewInfo")
  },
  settings: {
    getHomebrewPath: () => ipcRenderer.invoke("settings:getHomebrewPath"),
    validateHomebrewPath: (path) => ipcRenderer.invoke("settings:validateHomebrewPath", path),
    setHomebrewPath: (path) => ipcRenderer.invoke("settings:setHomebrewPath", path),
    clearHomebrewPath: () => ipcRenderer.invoke("settings:clearHomebrewPath")
  },
  packages: {
    listFormulae: () => ipcRenderer.invoke("packages:listFormulae"),
    listCasks: () => ipcRenderer.invoke("packages:listCasks"),
    search: (query) => ipcRenderer.invoke("packages:search", query),
    info: (request) => ipcRenderer.invoke("packages:info", request),
    install: (request) => ipcRenderer.invoke("packages:install", request),
    uninstall: (request) => ipcRenderer.invoke("packages:uninstall", request),
    installWithProgress: (request) => ipcRenderer.invoke("packages:installProgress", request),
    uninstallWithProgress: (request) => ipcRenderer.invoke("packages:uninstallProgress", request)
  },
  updates: {
    list: () => ipcRenderer.invoke("updates:list"),
    updateMetadata: () => ipcRenderer.invoke("updates:updateMetadata"),
    upgradePackage: (request) => ipcRenderer.invoke("updates:upgradePackage", request),
    upgradeAll: () => ipcRenderer.invoke("updates:upgradeAll"),
    upgradePackageWithProgress: (request) => ipcRenderer.invoke("updates:upgradePackageProgress", request),
    upgradeAllWithProgress: () => ipcRenderer.invoke("updates:upgradeAllProgress")
  },
  services: {
    list: () => ipcRenderer.invoke("services:list"),
    start: (request) => ipcRenderer.invoke("services:start", request),
    stop: (request) => ipcRenderer.invoke("services:stop", request),
    restart: (request) => ipcRenderer.invoke("services:restart", request)
  },
  cleanup: {
    preview: () => ipcRenderer.invoke("cleanup:preview"),
    run: () => ipcRenderer.invoke("cleanup:run")
  },
  doctor: {
    run: () => ipcRenderer.invoke("doctor:run")
  },
  brewfile: {
    export: () => ipcRenderer.invoke("brewfile:export"),
    read: (path) => ipcRenderer.invoke("brewfile:read", path)
  },
  progress: {
    cancel: (operationId) => ipcRenderer.invoke("operation:cancel", operationId),
    onEvent: (callback) => {
      const listener = (_event: Electron.IpcRendererEvent, payload: unknown) => callback(payload as ProgressEvent);
      ipcRenderer.on("operation:progress", listener);
      return () => ipcRenderer.removeListener("operation:progress", listener);
    }
  },
  app: {
    onShortcut: (callback) => {
      const listener = (_event: Electron.IpcRendererEvent, payload: unknown) => callback(payload as AppShortcut);
      ipcRenderer.on("app:shortcut", listener);
      return () => ipcRenderer.removeListener("app:shortcut", listener);
    }
  }
};

contextBridge.exposeInMainWorld("brewwery", api);
