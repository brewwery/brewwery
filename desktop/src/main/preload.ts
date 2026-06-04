import { contextBridge, ipcRenderer } from "electron";
import type { BrewweryApi } from "@brewwery/shared-types";

const api: BrewweryApi = {
  system: {
    detectHomebrew: () => ipcRenderer.invoke("system:detectHomebrew"),
    getBrewInfo: () => ipcRenderer.invoke("system:getBrewInfo")
  },
  packages: {
    listFormulae: () => ipcRenderer.invoke("packages:listFormulae"),
    listCasks: () => ipcRenderer.invoke("packages:listCasks")
  },
  updates: {
    list: () => ipcRenderer.invoke("updates:list"),
    upgradePackage: (request) => ipcRenderer.invoke("updates:upgradePackage", request),
    upgradeAll: () => ipcRenderer.invoke("updates:upgradeAll")
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
  }
};

contextBridge.exposeInMainWorld("brewwery", api);
