import { BrowserWindow, app, nativeImage, shell } from "electron";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import icon from "../../assets/brewwery-icon.png?asset";

const currentDir = dirname(fileURLToPath(import.meta.url));
const appIcon = nativeImage.createFromPath(icon);

export function createMainWindow(): BrowserWindow {
  if (process.platform === "darwin") {
    app.dock?.setIcon(appIcon);
  }

  const window = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 960,
    minHeight: 620,
    title: "Brewwery",
    titleBarStyle: "hiddenInset",
    trafficLightPosition: { x: 16, y: 18 },
    backgroundColor: "#111318",
    icon: appIcon,
    show: false,
    webPreferences: {
      preload: join(currentDir, "../preload/preload.cjs"),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false
    }
  });

  window.once("ready-to-show", () => window.show());

  window.webContents.setWindowOpenHandler(({ url }) => {
    void shell.openExternal(url);
    return { action: "deny" };
  });

  if (process.env.ELECTRON_RENDERER_URL) {
    void window.loadURL(process.env.ELECTRON_RENDERER_URL);
  } else {
    void window.loadFile(join(currentDir, "../renderer/index.html"));
  }

  return window;
}
