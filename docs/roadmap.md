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

## v0.2 Read-only Expansion

- Updates page with outdated package parsing
- Services page with service status
- Doctor page with parsed findings
- Brewfile parser and preview
- Better loading, empty, and error states

## v0.3 Controlled Actions

- Explicit install, uninstall, upgrade, and cleanup confirmation flows
- Operation history stored locally
- Terminal handoff for advanced commands

## Later

- Signed macOS builds
- Accessibility polish
- Contributor-friendly test fixtures

Linux and Windows support are intentionally out of scope for now.
