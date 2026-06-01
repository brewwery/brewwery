import { app, BrowserWindow } from "electron";
import { createAppMenu } from "./menu";
import { registerIpcHandlers } from "./ipc";
import { createMainWindow } from "./window";
import { createTray } from "./tray";

app.setName("Brewwery");

const gotLock = app.requestSingleInstanceLock();

if (!gotLock) {
  app.quit();
}

app.whenReady().then(() => {
  app.setName("Brewwery");
  app.setAboutPanelOptions({
    applicationName: "Brewwery"
  });
  createAppMenu();
  registerIpcHandlers();
  const mainWindow = createMainWindow();
  createTray(mainWindow);

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
