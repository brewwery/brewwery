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

Homebrew commands are requested through typed IPC and executed through predefined Homebrew operations. The Rust native core handles Homebrew detection, parsing, and normalized command operations. The Electron main process also includes allowlisted streaming operations for install, uninstall, and upgrade so stdout/stderr can be sent to the renderer as progress events.

There is no generic shell command IPC, no renderer shell access, and no sudo.

The only mutating v0.5 operations are:

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

Streaming progress operations still use fixed argv arrays and `shell: false`; the renderer receives progress events only and cannot provide arbitrary commands.

The v0.7.0-beta.1 Settings page can save a custom Homebrew path only after Rust validates that it is an absolute executable file and can run `brew --version`. The saved path is stored locally in Electron `userData` settings and is applied to both the Rust runner and streaming progress runner before falling back to default Homebrew detection paths.

Private beta security review coverage is tracked in `docs/private-beta-test-report.md`.

Operation history is stored locally in renderer `localStorage`. It is not sent to any server, synced, or used for telemetry. Users can search it, export it as JSON from the renderer, or clear it from the History page. Large stdout/stderr/details are trimmed before storage to keep the app responsive.

Settings diagnostics are copied to the clipboard only after explicit user action. They contain app/Homebrew metadata and local counts, not package history output.

The environment sets:

- `HOMEBREW_NO_AUTO_UPDATE=1`
- `HOMEBREW_NO_ANALYTICS=1`

Future mutating operations must require explicit user intent, confirmation, visible command summaries, and clear failure output.

IPC errors are normalized into stable codes so the UI can show specific recovery states instead of generic failure text.
