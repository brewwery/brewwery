import { app, BrowserWindow } from "electron";
import { createAppMenu } from "./menu";
import { registerIpcHandlers } from "./ipc";
import { createMainWindow } from "./window";
import { createTray } from "./tray";

app.setName("Brewwery");
let mainWindow: BrowserWindow | undefined;

const gotLock = app.requestSingleInstanceLock();

if (!gotLock) {
  app.quit();
}

app.whenReady().then(() => {
  app.setName("Brewwery");
  app.setAboutPanelOptions({
    applicationName: "Brewwery",
    applicationVersion: app.getVersion(),
    copyright: "MIT License. Made by Made Büro.",
    website: "https://github.com/brewwery/brewwery"
  });
  createAppMenu();
  registerIpcHandlers();
  mainWindow = createMainWindow();
  createTray(getOrCreateMainWindow);

  app.on("activate", () => {
    getOrCreateMainWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

function getOrCreateMainWindow(): BrowserWindow {
  if (mainWindow && !mainWindow.isDestroyed()) {
    return mainWindow;
  }

  mainWindow = BrowserWindow.getAllWindows().find((window) => !window.isDestroyed()) ?? createMainWindow();
  mainWindow.once("closed", () => {
    if (mainWindow?.isDestroyed()) {
      mainWindow = undefined;
    }
  });
  return mainWindow;
}
