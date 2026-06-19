# Roadmap

## v0.1 Foundation

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

- Updates page with outdated package parsing
- Upgrade one package and upgrade all flows with explicit confirmation
- Services page with service status
- Start, stop, and restart service flows with explicit confirmation
- Dashboard update and service counts backed by real data
- Typed IPC contracts for updates and services
- Rust allowlisted operations for updates and services
- Loading, empty, and error states for updates and services

## v0.3 Cleanup, Doctor & Brewfile

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

- Local operation history stored in renderer localStorage
- Upgrade, service, cleanup, doctor, and Brewfile export outcomes recorded
- Success and failure states with timestamps
- Command summaries and targets
- Expandable stdout, stderr, raw output, and error details
- History filters and clear action

## v0.3.2 History Polish

- Search inside operation history
- Export operation history as JSON from the renderer
- Compact result toasts after logged operations
- Toast dismissal and automatic timeout
- No additional IPC or shell command surface

## v0.4 Search & Discovery

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
- v0.5 security and distribution documentation

## v0.5.1 Custom Homebrew Path Validation

- Custom Homebrew executable path validation in Rust
- Absolute path, file existence, executable permission, and `brew --version` checks
- Persisted custom Homebrew path in Electron main process userData settings
- Rust runner uses the validated custom path before default detection paths
- Streaming progress runner uses the same validated custom path as the Rust runner
- Settings page can validate, save, and reset custom Homebrew path
- Tray Open Brewwery lifecycle crash fix

## v0.5.2 Alpha Hardening

- Version bump to 0.5.2 across workspace packages and Rust crate
- `package:mac:dir` command for packaged `.app` testing without DMG creation
- `package:clean` command for local packaging artifact cleanup
- Alpha QA checklist covering packaged app, tray, onboarding, settings, core UX, and safety checks
- README uninstall notes for local alpha app data
- Development documentation for packaging and alpha verification

## v0.6.0-alpha.1 Private Alpha

- Private alpha release notes draft
- Known issues document
- Private alpha install/uninstall instructions
- Packaged app verification docs
- Expanded private alpha QA checklist
- Release draft instructions for GitHub Releases
- Settings About release notes link
- Apple Silicon packaged `.app` verification path
- Final security review checklist for private alpha

## v0.6.0-alpha.2 Private Alpha Polish

- Settings Copy diagnostics action for private alpha reports
- Dashboard last-refreshed state
- Dashboard running-first service preview
- History failed-only filter
- `pnpm alpha:verify` command for local release verification
- `pnpm alpha:clean-install` helper for fresh local alpha testing
- Private alpha test report template
- v0.6.0-alpha.2 release notes draft

## v0.7.0-beta.1 Private Beta

- Private beta release notes draft
- Private beta test report template
- README status updated for private beta
- History render batching for large local operation logs
- History and progress output trimming for large brew stdout/stderr
- Friendly error messages with expandable technical details
- Packaged app native-core cleanup to keep artifacts smaller
- Local `.app` and ZIP verification path
- DMG delegated to GitHub Actions when local `hdiutil` fails
- Final private beta security checklist

## v0.7.1-beta.2 Beta Fixes

- Private beta release notes for beta.2
- Private beta guide and test report restored/updated
- `pnpm beta:clean-install` helper alias
- Local `.app` and ZIP rebuild
- ZIP integrity verification
- Bundle version and bundle identifier verification
- Local DMG `hdiutil create ... -fs APFS` issue documented
- GitHub Actions remains the clean-runner DMG path

## v0.7.2-beta.3 Beta QA Fixes

- Search installed state is reconciled from installed formulae/casks
- Formulae compare by `formula.name`
- Casks compare by `cask.token`
- Installed matching is case-insensitive
- Package detail drawer respects corrected installed state
- Invalid discovery search queries do not run `brew search`
- Cyrillic search input shows a friendly local state
- Stale search responses are ignored
- Search input remains responsive during long Homebrew searches
- Rust search validation uses the renderer allowlist
- Updates page includes explicit `Check for updates` action with confirmation
- The action runs `brew update`, logs to History, and reloads outdated package counts

## v0.8.0 Launch Candidate

- `APP_CHANNEL` set to `Launch Candidate`
- About and status bar show `Brewwery 0.8.0`
- Release notes added at `docs/release-notes/v0.8.0.md`
- Launch Candidate checklist added
- README and docs updated from beta wording to Launch Candidate wording
- Known limitations reviewed as Keep, Fixed, or Move to v0.9
- Package-detail placeholder actions hidden from primary UI
- Status bar disabled Terminal placeholder removed
- Button labels standardized across Updates, Cleanup, Doctor, and Brewfile
- Issue templates added for bugs and feature requests
- `pnpm release:verify` added as the primary verification script

## v0.8.1 Light Theme & Visual Polish

- Working Settings theme selector
- System, Dark, and warm Light theme modes
- Theme persisted in local Settings store
- Core shell and UI components moved to theme tokens
- Hardcoded dark raw-output and drawer surfaces replaced with theme-aware surfaces

## v0.8.2 Light Theme QA Polish

- Light theme sidebar logo made readable
- Light theme success, danger, and warning colors strengthened
- Status badges, dots, toasts, progress panels, and inline errors use shared theme tokens
- macOS window resize, maximize, and fullscreen controls restored
- Window centering shortcut remains available and centers on both axes

## v0.9.0 Release Candidate

Status: in progress.

- Version bump to `0.9.0`
- `APP_CHANNEL` set to `Release Candidate`
- About, status bar, and bundle metadata show `Brewwery 0.9.0`
- Release notes added at `docs/release-notes/v0.9.0.md`
- Release Candidate checklist added
- Signing and notarization preparation documented
- Known limitations reviewed and assigned to keep, fixed, or future release
- Apple Silicon remains the recommended v1.0 target
- Intel and universal builds are validation targets, with runtime testing documented as pending until an Intel Mac or dedicated runner is available

## Feature Freeze

After v0.9.0, only the following changes should land before v1.0:

- Bug fixes
- Documentation updates
- Packaging fixes
- QA findings
- Release pipeline polish
- Security review fixes

## v0.9.1 Discover & Favorites

Status: implemented as Release Candidate polish.

- Local Discover page with curated package collections
- Local Favorites page backed by Zustand persistence
- Favorite add/remove action in the package detail drawer
- Favorite indicators in Search, Discover, Packages, and Casks
- No new Homebrew commands or IPC channels
- No accounts, cloud sync, telemetry, paid logic, or donation/support logic

## v0.9.2 QA Fixes

Status: implemented.

- Settings `Check Homebrew` action for explicit `brew update`
- Search installed status badge polish
- Scrollable package detail drawer
- Discover collection summary polish
- Tapped formula identifier validation fix
- Favorite state immediate UI update
- Tray menu cleanup
- Documentation cleanup
- Packaging verification

## v0.9.3 Stability & Error Recovery

Status: implemented.

- Bounded stdout/stderr capture in Electron main and renderer progress state
- Retry actions for package, cask, update, service, cleanup preview, and doctor errors
- Rust unit tests for Homebrew formulae, casks, updates, services, cleanup, and doctor parsers
- Validation regression tests for formula, cask, search, upgrade, and service identifiers
- napi-rs `noop` test configuration for CI tests without a Node host
- Known issues split into external release constraints and engineering follow-ups
- No new Homebrew commands or IPC channels

## Later

- Signed and notarized macOS builds
- Universal macOS build validation
- Accessibility polish
- Contributor-friendly test fixtures

Linux and Windows support are intentionally out of scope for now.
