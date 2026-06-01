# Architecture

Brewwery is a macOS-first Electron app with a narrow main-process API over local Homebrew commands.

## Layers

- `desktop/src/main`: Electron lifecycle, windows, menu, tray, and IPC handlers.
- `desktop/src/renderer`: React UI, local state, pages, and reusable components.
- `packages/shared-types`: TypeScript contracts shared between main, preload, and renderer.
- `crates/brewwery-core`: Rust napi-rs core for predefined Homebrew detection, info, package listing, and JSON normalization.

## IPC

The renderer never shells out directly. It calls `window.brewwery`, exposed by the preload script, which forwards a small typed API to Electron IPC handlers. Electron main calls the Rust addon for Homebrew operations.

All IPC calls return `IpcResponse<T>`:

```ts
type IpcResponse<T> = {
  ok: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    raw?: string;
  };
};
```

Minimum error codes:

- `HOMEBREW_NOT_FOUND`
- `BREW_COMMAND_FAILED`
- `BREW_JSON_PARSE_FAILED`
- `PERMISSION_DENIED`
- `UNSUPPORTED_PLATFORM`
- `UNKNOWN_ERROR`

Current v0.1 channels:

- `system:detectHomebrew`
- `system:getBrewInfo`
- `packages:listFormulae`
- `packages:listCasks`

## Homebrew Access

Homebrew lookup checks `/opt/homebrew/bin/brew` and `/usr/local/bin/brew`, then optionally resolves `brew` from `PATH`. Commands are currently read-only:

- `brew --version`
- `brew --prefix`
- `brew config`
- `brew list --formula --json=v2`
- `brew list --cask --json=v2`

Homebrew 5 may reject `--json=v2` for `brew list`; in that case Brewwery falls back to:

- `brew list --formula --versions --json`
- `brew list --cask --versions --json`

The command environment sets `HOMEBREW_NO_AUTO_UPDATE=1` and `HOMEBREW_NO_ANALYTICS=1`.

Package JSON is normalized into Brewwery-owned `Formula` and `Cask` models before it reaches the UI.

There is no generic shell-command IPC. Rust only exposes predefined Homebrew operations for v0.1.
