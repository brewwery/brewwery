import { BrowserWindow, Menu, Tray, app, nativeImage } from "electron";
import type { AppShortcut } from "@brewwery/shared-types";
import icon from "../../assets/menu-bar-icon.png?asset";

let tray: Tray | undefined;

export function createTray(getMainWindow: () => BrowserWindow): Tray {
  const trayIcon = nativeImage.createFromPath(icon).resize({ width: 18, height: 18 });
  trayIcon.setTemplateImage(true);
  tray = new Tray(trayIcon);
  tray.setToolTip("Brewwery");
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: "Open Brewwery", click: () => showAndSend(getMainWindow()) },
      { label: "Check for updates", click: () => showAndSend(getMainWindow(), "updates") },
      { label: "Run doctor", click: () => showAndSend(getMainWindow(), "doctor") },
      { label: "Settings", click: () => showAndSend(getMainWindow(), "settings") },
      { type: "separator" },
      { label: "Quit", click: () => app.quit() }
    ])
  );
  return tray;
}

function showAndSend(mainWindow: BrowserWindow, shortcut?: AppShortcut) {
  if (mainWindow.isDestroyed()) return;
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.focus();
  if (shortcut) mainWindow.webContents.send("app:shortcut", shortcut);
}
