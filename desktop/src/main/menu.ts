import { BrowserWindow, Menu, app } from "electron";
import type { AppShortcut } from "@brewwery/shared-types";

export function createAppMenu(): void {
  const template: Electron.MenuItemConstructorOptions[] = [
    {
      label: app.name,
      submenu: [
        { role: "about" },
        { type: "separator" },
        {
          label: "Settings...",
          accelerator: "CommandOrControl+,",
          click: () => sendShortcut("settings")
        },
        { type: "separator" },
        { role: "hide" },
        { role: "hideOthers" },
        { role: "unhide" },
        { type: "separator" },
        { role: "quit" }
      ]
    },
    {
      label: "File",
      submenu: [
        {
          label: "Search Packages",
          accelerator: "CommandOrControl+K",
          click: () => sendShortcut("search")
        },
        {
          label: "Refresh Current Page",
          accelerator: "CommandOrControl+R",
          click: () => sendShortcut("refresh")
        },
        { type: "separator" },
        { role: "close", accelerator: "CommandOrControl+W" }
      ]
    },
    {
      label: "View",
      submenu: [
        { role: "toggleDevTools" },
        { type: "separator" },
        { role: "resetZoom" },
        { role: "zoomIn" },
        { role: "zoomOut" }
      ]
    },
    {
      label: "Window",
      submenu: [{ role: "minimize" }, { role: "close" }]
    }
  ];

  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

function sendShortcut(shortcut: AppShortcut) {
  const window = BrowserWindow.getFocusedWindow() ?? BrowserWindow.getAllWindows()[0];
  if (!window || window.isDestroyed()) return;
  if (window.isMinimized()) window.restore();
  window.show();
  window.webContents.send("app:shortcut", shortcut);
}
