# Roadmap

## v0.1 Foundation

Status: complete.

- pnpm workspace scaffold
- Electron, React, Vite, TypeScript app shell
- Tailwind CSS dark theme
- shadcn/ui-style components
- Zustand UI state
- Sidebar and status bar
- Shared IPC contracts
- Rust napi-rs core scaffold
- Homebrew detection and read-only package/cask listing

## v0.1.1 Package Detail & UX Polish

Status: complete.

- Package detail drawer for installed formulae
- Cask detail drawer for installed casks
- Local search for installed formulae and casks
- Simple sorting by name, version, and status where applicable
- Formula filters for all, on request, and dependencies
- Refresh action that refetches Homebrew info, formulae, and casks through typed IPC
- Copy package/token name and brew install command
- Homepage links from detail drawers
- Clear loading, empty, and error states
- Read-only UX with install, uninstall, upgrade, cleanup, and service actions still disabled or unimplemented

## v0.2 Updates & Services

Status: complete.

- Updates page with outdated package parsing
- Upgrade one package and upgrade all flows with explicit confirmation
- Services page with service status
- Start, stop, and restart service flows with explicit confirmation
- Dashboard update and service counts backed by real data
- Typed IPC contracts for updates and services
- Rust allowlisted operations for updates and services
- Loading, empty, and error states for updates and services

## v0.2.x Read-only Expansion

- Doctor page with parsed findings
- Brewfile parser and preview

## v0.3 Controlled Actions

- Explicit install, uninstall, and cleanup confirmation flows
- Operation history stored locally
- Terminal handoff for advanced commands

## Later

- Signed macOS builds
- Accessibility polish
- Contributor-friendly test fixtures

Linux and Windows support are intentionally out of scope for now.
