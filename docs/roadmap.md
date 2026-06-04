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

## v0.3 Cleanup, Doctor & Brewfile

Status: complete.

- Cleanup preview with parsed removable items and total size where available
- Cleanup run with explicit confirmation
- Brew doctor diagnostics parsing
- Brewfile export through a temporary file
- Brewfile read from validated local paths
- Brewfile entries grouped by type in the UI
- Typed IPC contracts for cleanup, doctor, and Brewfile
- Rust allowlisted operations for cleanup, doctor, and Brewfile
- Loading, empty, and error states for cleanup, doctor, and Brewfile

## v0.3.1 Operation Results & History

Status: complete.

- Local operation history stored in renderer localStorage
- Upgrade, service, cleanup, doctor, and Brewfile export outcomes recorded
- Success and failure states with timestamps
- Command summaries and targets
- Expandable stdout, stderr, raw output, and error details
- History filters and clear action

## v0.3.2 History Polish

Status: complete.

- Search inside operation history
- Export operation history as JSON from the renderer
- Compact result toasts after logged operations
- Toast dismissal and automatic timeout
- No additional IPC or shell command surface

## v0.4 Search & Discovery

Status: complete.

- Dedicated Homebrew discovery page
- Debounced search across Homebrew formulae and casks
- Loading, empty, Homebrew-not-found, and error states for search
- Package detail drawer for discovered formulae and casks
- Package metadata: homepage, latest version, installed version, dependencies, caveats, raw JSON details, and install command
- Install formulae and casks after explicit confirmation
- Uninstall formulae and casks after explicit confirmation
- Result toasts and operation history entries for install/uninstall
- Installed formulae/casks refresh after install and uninstall
- Rust allowlisted operations for search, info, install, and uninstall
- Strict package/cask token validation before mutating commands

## v0.4.1 Progress Output

Status: complete.

- Streaming progress events for package install
- Streaming progress events for package uninstall
- Streaming progress events for upgrade one package
- Streaming progress events for upgrade all packages
- Shared progress event IPC contracts
- Renderer progress output panel with stdout/stderr chunks
- History entries use final streamed stdout/stderr
- Existing confirmation modals remain required before every mutating operation
- No generic command runner or renderer shell access

## v0.5 Distribution & Polish

Status: complete.

- Production `electron-builder` macOS configuration
- Brewwery app metadata, bundle identifier, app category, app icon, and artifact naming
- Unsigned Apple Silicon DMG and ZIP packaging
- Root package scripts for macOS packaging
- GitHub Actions CI for dependency install, typecheck, lint, Rust tests, Rust build, Electron build, and artifact upload
- GitHub Actions release workflow for tag-based DMG/ZIP upload
- Basic tray menu with Open Brewwery, Check Updates, Run Doctor, Open Terminal, and Quit
- Keyboard shortcuts for search, refresh, settings, close window, and quit
- First-launch onboarding for Homebrew detected/not-found states
- Settings page with Homebrew path display, history export/clear, theme placeholder, app version, and About links
- Custom Homebrew path UI placeholder documented as a known limitation
- v0.5 security and distribution documentation

## Later

- Signed and notarized macOS builds
- Universal macOS build validation
- Accessibility polish
- Contributor-friendly test fixtures

Linux and Windows support are intentionally out of scope for now.
