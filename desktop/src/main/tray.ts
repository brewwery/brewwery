import { BrowserWindow, Menu, Tray, app, nativeImage } from "electron";
import icon from "../../assets/menu-bar-icon.png?asset";

let tray: Tray | undefined;

export function createTray(mainWindow: BrowserWindow): Tray {
  const trayIcon = nativeImage.createFromPath(icon).resize({ width: 18, height: 18 });
  trayIcon.setTemplateImage(true);
  tray = new Tray(trayIcon);
  tray.setToolTip("Brewwery");
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: "Show Brewwery", click: () => mainWindow.show() },
      { type: "separator" },
      { label: "Quit", click: () => app.quit() }
    ])
  );
  return tray;
}
