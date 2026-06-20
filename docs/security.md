# Security Model

Brewwery is a local-first macOS app. It should be conservative because it sits between the user and a package manager.

## Current Rules

- No telemetry.
- No authentication.
- No cloud sync.
- No monetization logic.
- No donations/support logic.
- No background mutation of Homebrew state.
- No arbitrary shell command execution.
- Mutating operations must be allowlisted and require explicit user confirmation.

## Electron Boundary

- Renderer uses `contextIsolation`.
- Renderer runs with `sandbox`.
- Node integration is disabled.
- The preload exposes only the `window.brewwery` API.
- External links are opened by the OS browser and denied inside app windows.

Favorites and Discover are local renderer features. Favorites are stored in local Zustand persistence, and Discover uses a static bundled registry. They do not add new IPC channels, shell commands, remote requests, telemetry, accounts, cloud sync, paid logic, or donation/support logic.

## Command Execution

Homebrew commands are requested through typed IPC and executed through predefined Homebrew operations. The Rust native core handles Homebrew detection, parsing, and normalized command operations. The Electron main process also includes allowlisted streaming operations for install, uninstall, and upgrade so stdout/stderr can be sent to the renderer as progress events.

There is no generic shell command IPC, no renderer shell access, and no sudo.

The only mutating v0.9 operations are:

- `brew install <formula>`
- `brew install --cask <cask>`
- `brew uninstall <formula>`
- `brew uninstall --cask <cask>`
- `brew upgrade <formula>`
- `brew upgrade --cask <cask>`
- `brew upgrade`
- `brew update`
- `brew services start <service>`
- `brew services stop <service>`
- `brew services restart <service>`
- `brew cleanup`

Cleanup is never run automatically and is only enabled after `brew cleanup -n` preview plus explicit confirmation.

Package names, service names, and Brewfile read paths are validated before being passed to Homebrew or the filesystem.

Formula identifiers accepted by install/uninstall/upgrade may use ASCII letters, digits, `@`, `-`, `_`, `.`, `+`, and slash-separated tap names such as `mongodb/brew/mongodb-community`. Cask tokens remain limited to ASCII letters, digits, `@`, `-`, `_`, `.`, and `+`. Spaces, shell metacharacters, redirection characters, leading/trailing slashes, repeated slashes, and newlines are rejected before Homebrew is invoked.

Streaming progress operations still use fixed argv arrays and `shell: false`; the renderer receives progress events only and cannot provide arbitrary commands.

The v0.9.5 Settings page can save a custom Homebrew path only after Rust validates that it is an absolute executable file and can run `brew --version`. The saved path is stored locally in Electron `userData` settings and is applied to both the Rust runner and streaming progress runner before falling back to default Homebrew detection paths.

Discovery search queries are validated in both the renderer and Rust core. Only ASCII package-name characters (`a-z`, `A-Z`, `0-9`, `@`, `-`, `_`, `.`, `+`) are accepted before an allowlisted `brew search` operation is run.

Homebrew metadata refresh is explicit. Brewwery does not run `brew update` automatically on startup or page load; the Updates and Settings pages require user confirmation before running the allowlisted `brew update` operation.

Streaming operation cancellation is scoped to the random active operation ID created by Electron main. The requesting renderer must own that operation. Renderer code cannot supply a PID, signal, executable, timeout, or command. Electron main uses fixed timeout policies and only signals child processes that Brewwery started itself.

Service streaming accepts only `start`, `stop`, or `restart` plans created in Electron main and validates the service name before spawning Homebrew. Cleanup streaming has no renderer-provided arguments and always runs the fixed `brew cleanup` command. Cleanup remains preview-first and confirmation-gated in the UI.

Release Candidate security review coverage is tracked in `docs/release-candidate-checklist.md`.

Signing and notarization preparation is tracked in `docs/signing-notarization.md`.

Operation history is stored locally in renderer `localStorage`. It is not sent to any server, synced, or used for telemetry. Users can search it, export it as JSON from the renderer, or clear it from the History page. Large stdout/stderr/details are trimmed before storage to keep the app responsive.

Settings diagnostics are copied to the clipboard only after explicit user action. They contain app/Homebrew metadata and local counts, not package history output.

The environment sets:

- `HOMEBREW_NO_AUTO_UPDATE=1`
- `HOMEBREW_NO_ANALYTICS=1`

Future mutating operations must require explicit user intent, confirmation, visible command summaries, and clear failure output.

IPC errors are normalized into stable codes so the UI can show specific recovery states instead of generic failure text.
