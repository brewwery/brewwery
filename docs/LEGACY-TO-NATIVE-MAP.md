# Legacy → Native Mapping

Every legacy module and its native replacement, so nothing can be dropped silently during the
rewrite. Paths on the left are relative to `apps/`, on the right to `Swift/`.

## Process and execution

| Legacy | Native |
| --- | --- |
| `crates/brewwery-core/src/runner.rs` | `Sources/BrewweryCore/Homebrew/HomebrewRunner.swift` |
| `desktop/src/main/ipc/operation-progress.ts` (spawn, cancel, timeouts) | `HomebrewRunner.stream(_:kind:id:)` + `Homebrew/OperationCoordinator.swift` |
| Node `child_process.spawn` | `Utilities/ChildProcess.swift` (`posix_spawn` in its own process group) |
| `runner.rs::run_brew_with_fallback` | `HomebrewRunner.run(_:fallback:)` |
| `HOMEBREW_NO_AUTO_UPDATE` / `HOMEBREW_NO_ANALYTICS` env | `Homebrew/HomebrewEnvironment.swift` |
| Electron IPC channels (43 of them) | removed — `HomebrewClient` is called directly |
| `preload.ts` `contextBridge` | removed — no bridge is needed in-process |

## Detection, commands and validation

| Legacy | Native |
| --- | --- |
| `system.rs::detect_homebrew` / `checked_paths` | `Homebrew/HomebrewDetector.swift` |
| `system.rs::validate_brew_path_internal` | `HomebrewDetector.validate(path:)` |
| `system.rs::set_custom_brew_path` / `clear_custom_brew_path` | `HomebrewDetector.setCustomPath` / `clearCustomPath` |
| `ipc/core.ts::applyStoredHomebrewPath` | `HomebrewDetector.applyStoredCustomPath(_:)` |
| argv literals scattered across the Rust modules | `Homebrew/HomebrewCommand.swift` (one closed enum) |
| `validate_formula_name` / `validate_cask_token` / `validate_service_name` / `validate_tap_name` / `validate_search_query` / `validate_brewfile_path` | `Homebrew/HomebrewIdentifier.swift` |
| `operation-progress.ts` duplicate JS validators | removed — the same Swift validators serve both paths |

## Models and parsers

| Legacy | Native |
| --- | --- |
| `packages.rs` DTOs + `normalize_*` | `Models/Package.swift`, `Parsers/PackageParser.swift` |
| `updates.rs` | `Models/Update.swift`, `Parsers/OutdatedParser.swift` |
| `services.rs` | `Models/Service.swift`, `Parsers/ServiceParser.swift` |
| `taps.rs` | `Models/Tap.swift`, `Parsers/TapParser.swift` |
| `cleanup.rs` | `Models/Cleanup.swift`, `Parsers/CleanupParser.swift` |
| `doctor.rs` | `Models/Doctor.swift`, `Parsers/DoctorParser.swift` |
| `brewfile.rs` | `Models/Brewfile.swift`, `Parsers/BrewfileParser.swift` |
| `system.rs::parse_brew_config` + `parser.rs` | `Parsers/BrewConfigParser.swift`, `Parsers/KeyValueParser.swift` |
| `packages/shared-types/src/*.ts` | the Swift model types themselves |
| `permissions.rs`, `filesystem.rs` | dropped — dead code in 0.9.7 |

## Errors and policy

| Legacy | Native |
| --- | --- |
| `errors.rs::BrewweryError` | `Errors/BrewweryError.swift` |
| `shared-types/ipc.ts::IpcErrorCode` | `Errors/BrewweryErrorCode.swift` (same raw strings) |
| `ipc/errors.ts::normalizeIpcError` + per-feature `map*Error` | `BrewweryError` constructors + the mapping helpers in `HomebrewClient.swift` |
| `renderer/lib/errors.ts` friendly copy | `BrewweryError.friendlyMessage` / `.details` |
| `main/external-links.ts` | `Utilities/ExternalLinkPolicy.swift` |

## State

| Legacy | Native |
| --- | --- |
| Zustand `ui-store` | `App/AppState.swift` |
| Zustand `package-store` + `hooks/use-packages.ts` | `Models/PackageLibrary.swift` |
| Zustand `settings-store` + `main/settings-storage.ts` | `Persistence/SettingsStore.swift` (`UserDefaults`) |
| Zustand `history-store` | `Persistence/HistoryStore.swift` (`history.json`) |
| Zustand `favorites-store` | `Persistence/FavoritesStore.swift` (`favorites.json`) |
| Zustand `toast-store` | `AppState.toasts` |
| `hooks/use-system.ts` | `Models/SystemModel.swift` |
| `hooks/use-updates.ts` | `Models/UpdatesModel.swift` + `AppEnvironment+Operations` |
| `hooks/use-services.ts` | `Models/ServicesModel.swift` + `AppEnvironment+Operations` |
| `hooks/use-cleanup.ts` | `Models/CleanupModel.swift` + `AppEnvironment.runCleanup()` |
| `hooks/use-doctor.ts` | `Models/DoctorModel.swift` |
| `hooks/use-brewfile.ts` | `Models/BrewfileModel.swift` |
| `hooks/use-package-discovery.ts` | `Models/SearchModel.swift`, `PackageInfoModel` |
| `hooks/use-package-actions.ts` | `App/AppEnvironment+Operations.swift` |
| `hooks/use-progress-operation.ts` | `Homebrew/OperationCoordinator.swift` |
| `hooks/use-debounced-value.ts` | `SearchModel`'s cancellable debounce `Task` |

## Application shell

| Legacy | Native |
| --- | --- |
| `main/index.ts` | `App/BrewweryApp.swift`, `App/AppDelegate.swift` |
| `main/window.ts` | `AppDelegate.configureMainWindow()` + `BrewweryApp` scene modifiers |
| `main/menu.ts` | `App/AppCommands.swift` |
| `main/tray.ts` | `AppDelegate.installStatusItem()` |
| `main/update-badge.ts` | `AppDelegate.startBackgroundBadgeRefresh()` |
| `electron-updater` (declared, never used) | `App/AppUpdateController.swift` (Sparkle seam) |
| `renderer/app.tsx` routing | `Features/Shell/RootView.swift` |
| `components/layout/app-shell.tsx` | `Features/Shell/RootView.swift` |
| `components/layout/titlebar.tsx` | dropped — see `ARCHITECTURE-DECISIONS.md` §15; search and Settings moved into `Features/Shell/GlobalSearchField.swift` |
| `components/layout/sidebar.tsx` | `Features/Shell/SidebarView.swift` |
| `components/layout/status-bar.tsx` | `Features/Shell/StatusBarView.swift` |
| `components/ui/toast-viewport.tsx` | `Features/Shell/ToastViewport.swift` |

## Design system

| Legacy | Native |
| --- | --- |
| `styles.css` custom properties | `DesignSystem/BrewweryColor.swift` |
| Tailwind spacing/typography classes | `DesignSystem/BrewweryMetrics.swift` |
| `components/ui/{button,input,badge,card,tabs,table}.tsx` | `DesignSystem/Components.swift` |
| `components/ui/state-panel.tsx` | `DesignSystem/StatePanel.swift` |
| `components/ui/virtualized-data-table.tsx` (`@tanstack/react-virtual`) | `DesignSystem/DataTable.swift` (`LazyVStack` + a `Layout` implementing the grid tracks) |
| `components/ui/confirmation-dialog.tsx` | `Features/Shared/ConfirmationDialog.swift` |
| `components/ui/operation-progress-panel.tsx` | `Features/Shared/OperationProgressPanel.swift` |
| `components/packages/package-detail-drawer.tsx` | `Features/Shared/PackageDetailDrawer.swift` |
| `components/onboarding/first-launch-onboarding.tsx` | dropped — see `ARCHITECTURE-DECISIONS.md` §15 |
| `lucide-react` icons | SF Symbols |
| `assets/*.png`, `*.svg` | `Sources/Brewwery/Resources/*.png` |

## Pages

| Legacy | Native |
| --- | --- |
| `pages/dashboard.tsx` | `Features/Dashboard/DashboardView.swift` |
| `pages/discover.tsx` + `lib/discover.ts` | `Features/Discover/DiscoverView.swift` + `Catalogs/DiscoverCatalog.swift` |
| `pages/search.tsx` | `Features/Search/SearchView.swift` |
| `pages/favorites.tsx` | `Features/Favorites/FavoritesView.swift` |
| `pages/packages.tsx` | `Features/Packages/PackagesView.swift` |
| `pages/casks.tsx` | `Features/Packages/CasksView.swift` |
| `pages/taps.tsx` | `Features/Taps/TapsView.swift` |
| `pages/updates.tsx` | `Features/Updates/UpdatesView.swift` |
| `pages/services.tsx` | `Features/Services/ServicesView.swift` |
| `pages/cleanup.tsx` | `Features/Cleanup/CleanupView.swift` |
| `pages/doctor.tsx` | `Features/Doctor/DoctorView.swift` |
| `pages/brewfile.tsx` + `lib/starter-brewfiles.ts` | `Features/Brewfile/BrewfileView.swift` + `Catalogs/StarterBrewfileCatalog.swift` |
| `pages/commands.tsx` + `lib/brew-commands.ts` | `Features/Commands/CommandsView.swift` + `Catalogs/CommandCatalog.swift` |
| `pages/history.tsx` | `Features/History/HistoryView.swift` |
| `pages/settings.tsx` + `lib/constants.ts` | `Features/Settings/SettingsView.swift` + `Catalogs/AppInfo.swift` |
| `pages/placeholder.tsx` | dropped — unused in 0.9.7 |
