# Changelog

All notable changes to Brewwery will be documented in this file.

## v0.5.1 - Tray Window Lifecycle Fix

Status: complete.

### Fixed

- Fixed a main-process crash when choosing Open Brewwery from the tray after the original window had been closed.
- Tray actions now resolve or create a live BrowserWindow before showing it or sending renderer shortcuts.

## v0.5.0 - Distribution & Polish

Status: complete.

### Added

- Production macOS `electron-builder` configuration.
- Brewwery app metadata, `com.brewwery.app` bundle identifier, macOS utility category, artifact naming, and app icon wiring.
- Unsigned Apple Silicon DMG and ZIP packaging through `pnpm package:mac`.
- Optional x64 and universal packaging scripts for later validation.
- GitHub Actions CI workflow for install, typecheck, lint, Rust tests, Rust build, Electron build, and artifact upload.
- GitHub Actions release workflow for tag-based DMG/ZIP upload to GitHub Releases.
- Tray menu with Open Brewwery, Check Updates, Run Doctor, Open Terminal, and Quit.
- Keyboard shortcuts for search, refresh current page, settings, close window, and quit.
- First-launch onboarding for detected Homebrew and Homebrew-not-found states.
- Settings page with detected Homebrew path, history export/clear, theme placeholder, manual update check, app version, and About links.

### Security

- Renderer shortcuts and tray actions use typed app events instead of exposing shell execution.
- Custom Homebrew path remains a documented placeholder until full validation is implemented across Rust and main-process runners.
- Packaging remains unsigned and not notarized for the public alpha.

## v0.4.1 - Progress Output

Status: complete.

### Added

- Progress event contracts for Homebrew operations.
- Allowlisted streaming operation handlers for install, uninstall, upgrade one package, and upgrade all packages.
- Renderer progress panel showing live stdout/stderr chunks while Homebrew runs.
- Progress output on Search, Packages, Casks, and Updates pages.
- History logging now uses final streamed stdout/stderr for install, uninstall, and upgrade operations.

### Security

- Streaming operations use fixed argv arrays with `shell: false`.
- Renderer receives progress events only and still cannot execute shell commands.
- Existing confirmation modals remain required before install, uninstall, and upgrade commands run.

## v0.4.0 - Search & Discovery

Status: complete.

### Added

- Dedicated Search page for Homebrew package discovery.
- Debounced search across formulae and casks using allowlisted Homebrew commands.
- Package info loading for formulae and casks with normalized metadata.
- Detail drawer support for discovered packages, installed state, latest version, dependencies, caveats, homepage, and raw JSON details.
- Install formula and cask flows with explicit confirmation.
- Uninstall formula and cask flows with explicit confirmation and warning copy.
- Install/uninstall operation history entries with command summary, stdout, stderr, and error details.
- Result toasts after install/uninstall operations.
- Installed formulae and casks refresh after package mutations.

### Security

- Added strict package and cask token validation before install/uninstall.
- Kept all commands allowlisted through typed IPC and the Rust napi-rs core.
- No generic shell command runner, no sudo, no telemetry, and no search-query logging.

## v0.3.2 - History Polish

Status: complete.

### Added

- Search field for local operation history.
- Export history as JSON from the renderer.
- Compact result toast notifications after logged operations.
- Toast viewport with success/error styling, dismiss action, and automatic timeout.

### Security

- History export is renderer-local and does not add filesystem IPC or shell execution.
- No telemetry, cloud sync, or network behavior was added.

## v0.3.1 - Operation Results & History

Status: complete.

### Added

- Local operation history store backed by renderer localStorage.
- History entries for package upgrades, service actions, cleanup runs, doctor runs, and Brewfile exports.
- Success and failure logging with timestamps, command summaries, targets, stdout, stderr, raw output, and error details.
- History page with summary cards, filters, expandable output details, copy output, and clear action.

### Security

- Operation history remains local-only.
- No telemetry, sync, cloud storage, or new IPC command execution surface was added.

## v0.3.0 - Cleanup, Doctor & Brewfile

Status: complete.

### Added

- Rust cleanup module with `preview_cleanup` and `run_cleanup`.
- Rust doctor module with `run_doctor`.
- Rust Brewfile module with `export_brewfile` and `read_brewfile`.
- Shared TypeScript contracts for cleanup previews/results, doctor diagnostics, and Brewfile entries/results.
- Typed IPC channels for cleanup, doctor, and Brewfile workflows.
- Renderer API wrapper methods and hooks for cleanup, doctor, and Brewfile.
- Cleanup page with preview-first workflow, parsed cleanup items, raw output details, and confirmation before `brew cleanup`.
- Doctor page with diagnostics, health state, raw output details, and copy diagnostics action.
- Brewfile page with export, copy, read-by-path, raw content, and grouped parsed entries.
- Error codes for cleanup, doctor, Brewfile, and invalid file paths.

### Security

- Cleanup execution requires explicit confirmation after preview.
- Doctor handles warning exit codes without treating them as fatal crashes.
- Brewfile export uses a temporary file path controlled by Brewwery.
- Brewfile read validates local paths before filesystem access.
- No arbitrary shell execution and no `sudo` usage.

## v0.2.0 - Updates & Services

### Added

- Rust updates module with `list_outdated`, `upgrade_package`, and `upgrade_all`.
- Rust services module with `list_services`, `start_service`, `stop_service`, and `restart_service`.
- Shared TypeScript contracts for outdated packages, upgrade requests/results, services, and service action results.
- Typed IPC channels for updates and services.
- Renderer API wrapper methods for updates and services.
- Updates page with real outdated formulae/casks from `brew outdated --json=v2`.
- Services page with real Homebrew service data from `brew services list --json`.
- Confirmation modals for package upgrades and service actions.
- Loading, empty, and error states for updates and services.
- Dashboard cards backed by real updates and services counts.

### Security

- Kept command execution allowlisted through the Rust addon.
- Added package and service name validation before running Homebrew commands.
- Preserved the renderer boundary: no direct shell access and no generic command IPC.
- No `sudo` usage.

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
