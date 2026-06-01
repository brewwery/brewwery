# Security Model

Brewwery is a local-first macOS app. It should be conservative because it sits between the user and a package manager.

## v0.1 Rules

- No telemetry.
- No authentication.
- No cloud sync.
- No monetization logic.
- No background mutation of Homebrew state.
- Read-only Homebrew commands only.

## Electron Boundary

- Renderer uses `contextIsolation`.
- Renderer runs with `sandbox`.
- Node integration is disabled.
- The preload exposes only the `window.brewwery` API.
- External links are opened by the OS browser and denied inside app windows.

## Command Execution

Homebrew commands are requested through typed IPC and executed by the Rust native core through predefined Homebrew operations. The app currently queries version, prefix, config, installed formulae, and installed casks.

There is no generic shell command IPC, no renderer shell access, no sudo, and no destructive command in v0.1.

The environment sets:

- `HOMEBREW_NO_AUTO_UPDATE=1`
- `HOMEBREW_NO_ANALYTICS=1`

Future mutating operations must require explicit user intent, confirmation, visible command summaries, and clear failure output.

IPC errors are normalized into stable codes so the UI can show specific recovery states instead of generic failure text.
