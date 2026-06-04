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

Homebrew commands are requested through typed IPC and executed by the Rust native core through predefined Homebrew operations. The app currently queries version, prefix, config, installed formulae, installed casks, outdated packages, Homebrew services, cleanup previews, doctor diagnostics, Brewfile exports, and Homebrew search/package info.

There is no generic shell command IPC, no renderer shell access, and no sudo.

The only mutating v0.4 operations are:

- `brew install <formula>`
- `brew install --cask <cask>`
- `brew uninstall <formula>`
- `brew uninstall --cask <cask>`
- `brew upgrade <formula>`
- `brew upgrade --cask <cask>`
- `brew upgrade`
- `brew services start <service>`
- `brew services stop <service>`
- `brew services restart <service>`
- `brew cleanup`

Cleanup is never run automatically and is only enabled after `brew cleanup -n` preview plus explicit confirmation.

Package names, service names, and Brewfile read paths are validated before being passed to Homebrew or the filesystem.

Package and cask identifiers accepted by install/uninstall are limited to ASCII letters, digits, `@`, `-`, `_`, `.`, and `+`. Spaces, shell metacharacters, redirection characters, and newlines are rejected before the Rust runner is invoked.

Operation history is stored locally in renderer `localStorage`. It is not sent to any server, synced, or used for telemetry. Users can search it, export it as JSON from the renderer, or clear it from the History page.

The environment sets:

- `HOMEBREW_NO_AUTO_UPDATE=1`
- `HOMEBREW_NO_ANALYTICS=1`

Future mutating operations must require explicit user intent, confirmation, visible command summaries, and clear failure output.

IPC errors are normalized into stable codes so the UI can show specific recovery states instead of generic failure text.
