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
  }
};

contextBridge.exposeInMainWorld("brewwery", api);
