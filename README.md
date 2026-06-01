# Brewwery

Brewwery is a clean macOS desktop app to manage Homebrew packages, casks, services, updates, cleanup, diagnostics, and Brewfiles in one place.

Current status: v0.1.1 Package Detail & UX polish / early alpha.

The project is open source, MIT licensed, and targets macOS first, with Apple Silicon as the primary platform.

See [CHANGELOG.md](CHANGELOG.md) for completed release notes.

## Features

- Detect local Homebrew installs in `/opt/homebrew` and `/usr/local`.
- Query Homebrew path, version, prefix, architecture, and config.
- List installed formulae and casks with read-only commands normalized into Brewwery models.
- Search, sort, refresh, and inspect installed formulae and casks.
- Copy package names and brew install commands from a read-only detail drawer.
- Provide a dark macOS utility UI with sidebar navigation and status bar.
- Define typed IPC contracts in a shared workspace package.
- Scaffold a Rust `napi-rs` core for future command parsing and execution.

## Supported v0.1 Commands

- `brew --version`
- `brew config`
- `brew list --formula --json=v2`
- `brew list --cask --json=v2`

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

Brewwery v0.1 uses read-only Homebrew commands and disables Homebrew auto-update and analytics in app-launched command environments. The renderer runs with context isolation, sandboxing, no Node integration, and a narrow preload API.

No authentication, telemetry, cloud sync, or monetization logic is included.

## Known Limitations

- Only Dashboard, Packages, and Casks use real data in v0.1.1.
- Services, Cleanup, Doctor, Brewfile, History, and Settings are clean stubs.
- No install, uninstall, upgrade, cleanup, sudo, or destructive commands are implemented.
- Package path and Terminal shortcuts are placeholders.
- Formula/cask descriptions depend on the JSON shape returned by the installed Homebrew version.

## License

MIT
