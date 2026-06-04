# Brewwery

Brewwery is a clean macOS desktop app to manage Homebrew packages, casks, services, updates, cleanup, diagnostics, and Brewfiles in one place.

Current status: v0.4 Search & Discovery / early alpha.

The project is open source, MIT licensed, and targets macOS first, with Apple Silicon as the primary platform.

See [CHANGELOG.md](CHANGELOG.md) for completed release notes.

## Features

- Detect local Homebrew installs in `/opt/homebrew` and `/usr/local`.
- Query Homebrew path, version, prefix, architecture, and config.
- List installed formulae and casks with read-only commands normalized into Brewwery models.
- Search, sort, refresh, and inspect installed formulae and casks.
- Copy package names and brew install commands from a read-only detail drawer.
- Show outdated formulae and casks from Homebrew.
- Upgrade one package or all outdated packages after explicit confirmation.
- Show Homebrew services and run start, stop, or restart after explicit confirmation.
- Preview Homebrew cleanup output and run cleanup only after confirmation.
- Run brew doctor and review parsed diagnostics.
- Export and inspect Brewfile contents.
- Review local operation history with timestamps and output details.
- Search operation history, export it as JSON, and see compact result toasts after operations.
- Search Homebrew formulae and casks through a dedicated discovery page.
- Inspect discovered package metadata, including homepage, latest version, dependencies, caveats, and install command.
- Install and uninstall formulae/casks after explicit confirmation, with operation history and result toasts.
- Provide a dark macOS utility UI with sidebar navigation and status bar.
- Define typed IPC contracts in a shared workspace package.
- Scaffold a Rust `napi-rs` core for future command parsing and execution.

## Supported Commands

- `brew --version`
- `brew config`
- `brew list --formula --json=v2`
- `brew list --cask --json=v2`
- `brew outdated --json=v2`
- `brew upgrade <formula>`
- `brew upgrade --cask <cask>`
- `brew upgrade`
- `brew services list --json`
- `brew services start <service>`
- `brew services stop <service>`
- `brew services restart <service>`
- `brew cleanup -n`
- `brew cleanup`
- `brew doctor`
- `brew bundle dump --force --file=<path>`
- `brew search --formula <query>`
- `brew search --cask <query>`
- `brew info --json=v2 <formula>`
- `brew info --cask --json=v2 <cask>`
- `brew install <formula>`
- `brew install --cask <cask>`
- `brew uninstall <formula>`
- `brew uninstall --cask <cask>`

Homebrew 5 may reject `--json=v2` for `brew list`; Brewwery then falls back to `brew list --formula --versions --json` or `brew list --cask --versions --json`.

## Stack

- Electron
- React
- TypeScript
- Vite and electron-vite
- Tailwind CSS
- shadcn/ui-style local components
- Zustand
- Rust core compiled with napi-rs
- pnpm workspaces

## Project Structure

```text
.
├── desktop/                 # Electron desktop app
├── crates/brewwery-core/    # Rust napi-rs core scaffold
├── packages/shared-types/   # Shared TypeScript contracts
├── docs/                    # Architecture, security, roadmap, development
├── scripts/                 # Local helper scripts
└── package.json             # pnpm workspace root
```

## Getting Started

Install Node.js 24 and pnpm 10, then run:

```bash
pnpm install
pnpm dev
```

Build the desktop app:

```bash
pnpm build
```

Build the Rust native core:

```bash
pnpm --filter @brewwery/brewwery-core build
```

## Security Model

Brewwery uses typed, allowlisted Homebrew commands and disables Homebrew auto-update and analytics in app-launched command environments. Mutating operations in v0.4 are limited to package install/uninstall, package upgrades, Homebrew service start/stop/restart, and cleanup after preview. Every mutating operation requires explicit confirmation. The renderer runs with context isolation, sandboxing, no Node integration, and a narrow preload API.

No authentication, telemetry, cloud sync, or monetization logic is included.

## Known Limitations

- Dashboard, Packages, Casks, Updates, Services, Cleanup, Doctor, Brewfile, and History use real local data.
- Settings is a clean stub.
- No sudo or arbitrary shell command is implemented.
- Tapped formula names containing `/` are rejected by the strict v0.4 package-name validator.
- Search result rows show lightweight data first; full metadata loads when a package detail is opened.
- Package path and Terminal shortcuts are placeholders.
- Formula/cask descriptions depend on the JSON shape returned by the installed Homebrew version.

## License

MIT
