# Security Model

Brewwery is a local-first macOS app. It should be conservative because it sits between the user and a package manager.

## Current Rules

- No telemetry.
- No authentication.
- No cloud sync.
- No monetization logic.
- No background mutation of Homebrew state.
- No arbitrary shell command execution.
- Mutating operations must be allowlisted and require explicit user confirmation.

## Electron Boundary

- Renderer uses `contextIsolation`.
- Renderer runs with `sandbox`.
- Node integration is disabled.
- The preload exposes only the `window.brewwery` API.
- External links are opened by the OS browser and denied inside app windows.

## Command Execution

Homebrew commands are requested through typed IPC and executed by the Rust native core through predefined Homebrew operations. The app currently queries version, prefix, config, installed formulae, installed casks, outdated packages, and Homebrew services.

There is no generic shell command IPC, no renderer shell access, no sudo, and no destructive command in v0.2.

The only mutating v0.2 operations are:

- `brew upgrade <formula>`
- `brew upgrade --cask <cask>`
- `brew upgrade`
- `brew services start <service>`
- `brew services stop <service>`
- `brew services restart <service>`

Package and service names are validated before being passed to Homebrew.

The environment sets:

- `HOMEBREW_NO_AUTO_UPDATE=1`
- `HOMEBREW_NO_ANALYTICS=1`

Future mutating operations must require explicit user intent, confirmation, visible command summaries, and clear failure output.

IPC errors are normalized into stable codes so the UI can show specific recovery states instead of generic failure text.
