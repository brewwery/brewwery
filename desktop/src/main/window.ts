import { BrowserWindow, app, nativeImage, screen, shell } from "electron";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import icon from "../../assets/brewwery-icon.png?asset";
import { isAllowedExternalUrl } from "./external-links";

const currentDir = dirname(fileURLToPath(import.meta.url));
const appIcon = nativeImage.createFromPath(icon);
const defaultWindowSize = {
  width: 1180,
  height: 920
};
const minimumWindowSize = {
  width: 960,
  height: 680
};

function centerWindow(window: BrowserWindow): void {
  const display = screen.getDisplayMatching(window.getBounds());
  const { x, y, width, height } = display.workArea;
  const bounds = window.getBounds();

  window.setPosition(
    Math.round(x + (width - bounds.width) / 2),
    Math.round(y + (height - bounds.height) / 2)
  );
}

export function createMainWindow(): BrowserWindow {
  if (process.platform === "darwin") {
    app.dock?.setIcon(appIcon);
  }

  const window = new BrowserWindow({
    ...defaultWindowSize,
    minWidth: minimumWindowSize.width,
    minHeight: minimumWindowSize.height,
    resizable: true,
    maximizable: true,
    fullscreenable: true,
    center: true,
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

  window.webContents.on("before-input-event", (event, input) => {
    if (input.type !== "keyDown") return;
    if (!input.control || input.meta || input.alt || input.shift) return;
    if (input.key.toLowerCase() !== "c" && input.code !== "KeyC") return;

    event.preventDefault();
    if (window.isMinimized()) window.restore();
    centerWindow(window);
    window.show();
    window.focus();
  });

  window.once("ready-to-show", () => {
    centerWindow(window);
    window.show();
  });

  window.webContents.setWindowOpenHandler(({ url }) => {
    if (isAllowedExternalUrl(url)) {
      void shell.openExternal(url);
    }
    return { action: "deny" };
  });

  if (process.env.ELECTRON_RENDERER_URL) {
    void window.loadURL(process.env.ELECTRON_RENDERER_URL);
  } else {
    void window.loadFile(join(currentDir, "../renderer/index.html"));
  }

  return window;
}
