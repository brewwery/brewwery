# Changelog

All notable changes to Brewwery will be documented in this file.

## v0.1.1 - Package Detail & UX Polish

Status: complete.

### Added

- Package detail drawer for installed Homebrew formulae.
- Cask detail drawer for installed Homebrew casks.
- Local search for formulae and casks.
- Sorting by name, installed version, and status where applicable.
- Formula filters for all formulae, installed on request, and dependencies.
- Refresh action that refetches Homebrew info, formulae, and casks through typed IPC.
- Copy package name, cask token, and brew install command actions.
- Homepage links from package and cask detail drawers.
- Improved loading, empty, and error states for package/cask views.
- Brewwery UI logotype in the sidebar.

### Changed

- Kept v0.1.1 read-only: install, uninstall, upgrade, cleanup, and service actions remain unimplemented or disabled.
- Replaced Electron/default visual branding with Brewwery app, dock, menu bar, and UI assets.
- Improved macOS app metadata for packaged builds.

## v0.1.0 - Foundation

Status: complete.

### Added

- pnpm workspace monorepo scaffold.
- Electron, React, TypeScript, Vite desktop app foundation.
- Tailwind CSS dark theme setup.
- shadcn/ui-style local UI components.
- Zustand UI/application state stores.
- macOS-style app shell with sidebar, titlebar, and status bar.
- Rust `brewwery-core` napi-rs crate scaffold.
- Shared TypeScript IPC contracts in `packages/shared-types`.
- Typed IPC bridge from renderer to Electron main.
- Homebrew detection using `/opt/homebrew/bin/brew`, `/usr/local/bin/brew`, and PATH fallback.
- Homebrew info query for version, prefix, architecture, and path.
- Formula listing through Homebrew JSON output normalized by Rust.
- Cask listing through Homebrew JSON output normalized by Rust.
- Dashboard with real Homebrew status and package counts.
- Packages page rendering real installed formulae.
- Casks page rendering real installed casks.
- Status bar with Homebrew version, prefix, architecture, formula count, and cask count.
- Error response model with stable IPC error codes.
- Security documentation and early alpha project docs.

### Security

- Renderer cannot execute shell commands.
- No generic shell command IPC exists.
- All renderer operations go through typed `brewweryApi` methods.
- Electron main calls the Rust addon for Homebrew operations.
- Rust only runs predefined read-only Homebrew commands.
- No `sudo` usage.
- No destructive commands in v0.1.

### Known Limitations

- Services, Cleanup, Doctor, Brewfile, History, and Settings are still stubs.
- Install, uninstall, upgrade, cleanup, and service control actions are not implemented.
- Linux and Windows support are intentionally out of scope.
