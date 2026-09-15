# Brewwery — Phase 0 Migration Audit

Audit of the legacy implementation in `apps/` (Electron + React + TypeScript + Rust/napi-rs,
version 0.9.7) performed before any Swift code was written. The legacy tree is the behavioural
specification for the native rewrite in `Swift/`.

Legacy source inspected in full:

* `apps/crates/brewwery-core/src/*.rs` (1 910 lines)
* `apps/desktop/src/main/**` (Electron main, preload, IPC — 1 857 lines)
* `apps/desktop/src/renderer/**` (React UI, stores, hooks — 8 222 lines)
* `apps/packages/shared-types/src/*.ts` (IPC contracts)
* `apps/docs/{architecture,security}.md`, `README.md`, `electron-builder.yml`

---

## A. Current architecture

### A.1 Process layout

```
React renderer (sandboxed, contextIsolation, nodeIntegration off)
  → window.brewwery (preload contextBridge)
    → ipcRenderer.invoke(<channel>)
      → Electron main ipcMain.handle
        → either  (a) Rust napi addon @brewwery/brewwery-core   [blocking, buffered]
           or     (b) child_process.spawn(brew, argv)           [streaming, cancellable]
            → Homebrew
```

Two distinct execution paths exist and they are **not** interchangeable:

| Path | Used by | Characteristics |
| --- | --- | --- |
| Rust napi core (`runner.rs::run_brew_output`) | all reads, `brew update`, taps, cleanup preview, doctor, brewfile | synchronous `Command::output()`, whole output buffered and **trimmed**, non-zero exit → `CommandFailed(stderr)` |
| Electron `spawn` (`ipc/operation-progress.ts`) | install, uninstall, upgrade, upgrade-all, service start/stop/restart, cleanup run | `shell:false`, live stdout/stderr chunks, cancellable, per-kind timeout, one operation per window |

Both set `HOMEBREW_NO_AUTO_UPDATE=1` and `HOMEBREW_NO_ANALYTICS=1`. The spawn path inherits
`process.env` and overrides those two keys; the Rust path passes only those two `.env()` calls on
top of the inherited environment.

### A.2 State management

Zustand stores in the renderer:

| Store | Persisted | Key | Contents |
| --- | --- | --- | --- |
| `ui-store` | no | — | `activePage`, `searchQuery` |
| `package-store` | no | — | `formulae[]`, `casks[]` (shared cache across pages) |
| `settings-store` | yes (localStorage) | `brewwery-settings` v2 | `firstLaunchComplete`, `theme`, `showPrereleaseUpdates`, `customHomebrewPath` |
| `history-store` | yes (localStorage) | `brewwery-operation-history` v1 | max 100 `OperationLogEntry`, newest first |
| `favorites-store` | yes (localStorage) | `brewwery-favorites` v1 | `FavoritePackage[]` |
| `toast-store` | no | — | max 3 toasts, auto-dismiss 4 200 ms |

Main-process persistence: `app.getPath("userData")/settings.json` holding only `{ homebrewPath }`.
This is the authoritative custom-path store; the renderer mirrors it into its own settings store on
Settings-page mount.

### A.3 Updates / packaging

No Sparkle and no working auto-update: `electron-updater` is a dependency but is never imported.
Packaging is `electron-builder`, appId `com.brewwery.app`, category `public.app-category.utilities`,
hardened runtime on, unsigned/un-notarised DMG + ZIP, arm64 primary.

---

## B. Feature inventory

Fifteen pages, all reachable from the sidebar (no routing library — `ui-store.activePage` +
a `pages` record in `app.tsx`; the page is remounted with `key={activePage:refreshKey}` so ⌘R
re-runs every page-level effect).

| # | Page | Sub-features |
| --- | --- | --- |
| 1 | **Dashboard** | Homebrew status strip; 4 stat cards (formulae, casks, updates, services); Services card (running/stopped/error pills + first 5, running-first); Updates card (mini bars formulae/casks + first 6); Homebrew info grid (6 fields); "Refresh data" refreshes system+formulae+casks+updates+services and stamps `lastRefreshed`; skeleton rows while loading; per-card inline errors and empty lines |
| 2 | **Discover** | 12 hard-coded collections; collection buttons; per-collection summary badges (packages/installed/favorites/available); package cards with kind badge, installed badge, Details / Install / favorite-toggle; install confirmation |
| 3 | **Search** | title-bar or page search field, 350 ms debounce, query validation, stale-response guard, results table (package/kind/status/details), detail drawer, install + uninstall with confirmation, progress panel |
| 4 | **Favorites** | table of saved packages, display-name resolution against installed lists, installed/available status, Details, remove |
| 5 | **Packages** | installed formulae, local filter field, filter tabs (all/leaves/on-request/dependencies), sort tabs (name/version/status), virtualised table, detail drawer, uninstall + confirmation, progress panel |
| 6 | **Casks** | same as Packages minus filters (single "All casks" tab) |
| 7 | **Taps** | list (sorted, official flag), add field (Enter submits), remove button, confirmations, history entries |
| 8 | **Updates** | 3 summary cards; "Refresh list" (`brew outdated`), "Check for updates" (`brew update` + confirm), "Upgrade all" (confirm); per-row Upgrade; pinned badge; progress panel |
| 9 | **Services** | 4 summary cards; table with status badge, user, file, command; Start/Stop/Restart with confirmation and per-status disabling; progress panel |
| 10 | **Cleanup** | preview-first policy note; "Preview cleanup" (`brew cleanup -n`); "Run cleanup" enabled only after a preview with ≥1 item; preview table (item/kind/size/path) + raw output disclosure; result panel; progress panel |
| 11 | **Doctor** | "Run doctor", "Copy diagnostics"; healthy state; diagnostics cards with severity badge; raw-output disclosure |
| 12 | **Brewfile** | Export (`brew bundle dump --force --file=<temp>`); Read an absolute Brewfile path; entry group cards (tap/brew/cask/mas/service/unknown, first 8 + "+N more"); generated Brewfile pane with line count; Copy; 5 starter Brewfile templates with per-card copy |
| 13 | **Commands** | 6 documentation links (opened through the main-process allowlist) + 7 command-reference sections with per-row copy |
| 14 | **History** | 4 summary cards; search field; 12 filter tabs; operation cards with kind/status/timestamp/target/command/error box/output disclosure; Copy; Export JSON; Clear; paged 40 at a time |
| 15 | **Settings** | Homebrew info grid (6 boxes); custom path Validate/Save/Reset; Refresh data; Check Homebrew (confirm); Appearance system/dark/light; History export/clear; About grid + Copy diagnostics + 4 external links |

Global chrome: title bar (drag region, app name, search field with clear button, settings button),
sidebar (logo, 3 sections, Homebrew status card), status bar (status dot, version, prefix, arch,
formula/cask counts, app version), toast viewport, first-launch onboarding overlay, package detail
drawer, confirmation dialogs, operation progress panel.

---

## C. Command inventory

Exact argv arrays issued by the legacy app:

| Operation | argv | Path |
| --- | --- | --- |
| detect / validate | `--version` | direct `Command`, not via runner |
| brew info | `config`, then `--version` | Rust |
| list formulae | `list --formula --json=v2` → fallback `list --formula --versions --json` | Rust |
| list casks | `list --cask --json=v2` → fallback `list --cask --versions --json` | Rust |
| leaves | `leaves` | Rust |
| dependents | `uses --installed <name>` | Rust |
| search | `search --formula <q>` then `search --cask <q>` | Rust |
| formula info | `info --json=v2 <name>` | Rust |
| cask info | `info --cask --json=v2 <token>` | Rust |
| install | `install <name>` / `install --cask <token>` | Rust *and* spawn |
| uninstall | `uninstall <name>` / `uninstall --cask <token>` | Rust *and* spawn |
| outdated | `outdated --json=v2` | Rust |
| metadata update | `update` | Rust |
| upgrade one | `upgrade <name>` / `upgrade --cask <token>` | Rust *and* spawn |
| upgrade all | `upgrade` | Rust *and* spawn |
| taps | `tap` | Rust |
| add / remove tap | `tap <name>` / `untap <name>` | Rust |
| services list | `services list --json` | Rust |
| service action | `services start|stop|restart <name>` | Rust *and* spawn |
| cleanup preview | `cleanup -n` | Rust |
| cleanup run | `cleanup` | Rust *and* spawn |
| doctor | `doctor` | Rust, **permissive** (non-zero exit tolerated) |
| brewfile export | `bundle dump --force --file=<tmp>/brewwery-Brewfile-<pid>` | Rust |

The UI only ever reaches the **spawn** variants for the mutating operations; the Rust
`install/uninstall/upgrade/cleanup/service` entry points are dead code in the shipped flows.

The fallback rule (`run_brew_with_fallback`) fires only when the error text contains
`needless argument`.

---

## D. Rust module → Swift mapping

| Rust | Swift |
| --- | --- |
| `runner.rs` | `Core/Homebrew/HomebrewRunner.swift` |
| `system.rs` (detect/validate/custom path) | `Core/Homebrew/HomebrewDetector.swift`, `HomebrewEnvironment.swift` |
| `errors.rs` | `Core/Errors/BrewweryError.swift` |
| `packages.rs` | `Core/Models/Package.swift`, `Core/Parsers/PackageParser.swift`, `Core/Homebrew/HomebrewClient+Packages.swift` |
| `updates.rs` | `Core/Models/Update.swift`, `Core/Parsers/OutdatedParser.swift` |
| `services.rs` | `Core/Models/Service.swift`, `Core/Parsers/ServiceParser.swift` |
| `taps.rs` | `Core/Models/Tap.swift`, `Core/Parsers/TapParser.swift` |
| `cleanup.rs` | `Core/Models/Cleanup.swift`, `Core/Parsers/CleanupParser.swift` |
| `doctor.rs` | `Core/Models/Doctor.swift`, `Core/Parsers/DoctorParser.swift` |
| `brewfile.rs` | `Core/Models/Brewfile.swift`, `Core/Parsers/BrewfileParser.swift` |
| `parser.rs` (`parse_key_value_lines`) | `Core/Parsers/KeyValueParser.swift` |
| `permissions.rs`, `filesystem.rs` | dropped — dead code (`is_mutating_operation_allowed()` always `false`, never called) |
| `ipc/operation-progress.ts` | `Core/Homebrew/HomebrewOperationCoordinator.swift` + `HomebrewRunner.stream` |
| `ipc/errors.ts` | `Core/Errors/BrewweryError+Mapping.swift` |
| `external-links.ts` | `Core/Utilities/ExternalLinkPolicy.swift` |
| `settings-storage.ts` | `Core/Persistence/SettingsStore.swift` |
| Zustand `history-store` | `Core/Persistence/HistoryStore.swift` |
| Zustand `favorites-store` | `Core/Persistence/FavoritesStore.swift` |

---

## E. UI inventory

**Screens** — dashboard, discover, search, favorites, packages, casks, taps, updates, services,
cleanup, doctor, brewfile, commands, history, settings.

**Sidebar** — `Library`: Dashboard, Discover, Search, Favorites, Packages, Casks, Taps, Updates.
`System`: Services, Cleanup, Doctor, Brewfile, Commands. `App`: History, Settings.

**Overlays** — first-launch onboarding (modal card, max-w-xl), package detail drawer (right, 420 pt,
scrim, Esc to close), confirmation dialog (centred, max-w-md, Esc cancels unless loading),
toast viewport (bottom-right, 360 pt, 3 max).

**Inline panels** — `StatePanel` (loading / empty / error / homebrew, min-height 256 pt, centred
icon + title + description + action), `OperationProgressPanel`, error disclosure (`Show details`
with code + raw `pre`).

**Menus** — app menu (About, Settings ⌘,, Hide/HideOthers/Unhide, Quit), File (Search Packages ⌘K,
Refresh Current Page ⌘R, Close ⌘W), View (Toggle DevTools, zoom), Window (Minimize, Close).
Tray/menu-bar item: Open Brewwery, Check for updates, Run doctor, Settings, Quit.
`Ctrl+C` (no other modifiers) re-centres and focuses the window.

**Empty/loading/error states** — every feature page carries a distinct `HOMEBREW_NOT_FOUND` panel
listing `/opt/homebrew/bin/brew` and `/usr/local/bin/brew`, a parse-specific error title, and a
Retry action.

---

## F. State inventory

* **Global** — Homebrew detection + info (re-fetched per hook instance), installed formulae/casks
  (shared Zustand cache), active page, search query.
* **Feature** — outdated list + `lastChecked`, services, taps, cleanup preview/result, doctor
  result, brewfile result, per-page filters/sorts/queries, selected row, pending confirmation.
* **Persisted** — settings (theme, first launch, prerelease flag, custom path), favorites, history,
  main-process `settings.json` (`homebrewPath`).
* **Transient** — toasts, progress operation state (lines capped at 80, stdout/stderr capped at
  120 000 chars in the renderer and 200 000 in main), copied-to-clipboard flags.

Notably **not** persisted: window frame, sidebar selection, table sort, filters, search query.

---

## G. Security inventory

* No generic shell IPC, no `sh -c`, no sudo, no telemetry, no network calls of Brewwery's own.
* Allowlisted external URLs only, HTTPS only, exact host match, optional path prefix:
  `www.brewwery.com`, `brewwery.com`, `docs.brewwery.com`, `brew.sh`, `docs.brew.sh`,
  `github.com/brewwery/brewwery` (prefix).
* Formula identifier: non-empty, ≤120 chars (≤160 in the upgrade path), no leading/trailing `/`,
  no `//`, characters `[A-Za-z0-9@._+\-/]`.
* Cask token: non-empty, ≤120 (≤160 upgrade), characters `[A-Za-z0-9@._+\-]` (no slash).
* Service name: non-empty, ≤120, characters `[A-Za-z0-9@._+\-]`.
* Search query: non-empty after trim, ≤80, characters `[A-Za-z0-9@._+\-]` (ASCII only; the renderer
  additionally rejects before dispatch).
* Tap name: exactly one `/`, both halves non-empty, ≤160 total, characters `[A-Za-z0-9._\-]`.
* Brewfile read path: absolute, existing regular file, no NUL, basename `brewfile` or `*.brewfile`
  (case-insensitive), ≤1 000 000 bytes.
* Custom Homebrew path: absolute, exists, regular file, mode & 0o111 ≠ 0, `brew --version` exits 0.
* Cancellation is scoped to a UUID owned by the requesting window; the renderer cannot pass a PID,
  signal, executable, or timeout.
* Every mutating operation is confirmation-gated in the UI; cleanup is additionally preview-gated.
* Operation timeouts: install 45 min, uninstall 15 min, upgrade 45 min, service 5 min,
  cleanup 30 min. SIGTERM, then SIGKILL after 5 s.
* One streaming operation per window at a time → `OPERATION_IN_PROGRESS`.

---

## H. Native migration plan

0. Audit (this document).
1. SwiftPM package, logging, errors, design system, test target.
2. Homebrew core: detection, environment, typed commands, validation, runner, streaming,
   cancellation, coordinator. Tests first.
3. Models + parsers ported from Rust with the Rust unit tests reused as fixtures.
4. Read-only features: dashboard, packages, casks, discover, search, details, updates, services,
   taps.
5. Mutations: install, uninstall, upgrade, update, service actions, tap actions, cleanup —
   with confirmation, streaming, cancellation, history.
6. Advanced tools: doctor, brewfile, cleanup preview, history.
7. Settings, commands/shortcuts, menu bar, status item, window behaviour, Sparkle.
8. Visual parity pass.
9. QA.

---

## I. Risk list

| Risk | Mitigation |
| --- | --- |
| Child processes surviving cancellation (`brew` spawns `git`, `curl`, `ruby`) | run each operation in its own process group and signal the **group**, not just the leader — strictly better than the legacy behaviour, which only signalled the direct child |
| Deadlock on full pipe buffers for long installs | read stdout and stderr concurrently with `AsyncStream` bridged from `readabilityHandler`, never `waitUntilExit()` before draining |
| Rust `trim()` semantics | every buffered command output is trimmed exactly as `run_brew_output` did; streaming chunks are **not** trimmed until the final event |
| Doctor exit code | `brew doctor` returns 1 when it finds warnings; must use the permissive runner |
| `--json=v2` rejection on Homebrew 5 | port `run_brew_with_fallback`, triggered only by `needless argument` |
| Cask `installed` / `name` polymorphism (string vs array) | dedicated `StringOrArray` decoding helper, covered by tests |
| Large lists (68+ formulae today, thousands possible) | `List` with stable identity + `Table`-style row views; parsing off the main actor |
| Swift 6 strict concurrency across `Process` | runner is an `actor`; `Process`/`Pipe` never cross isolation boundaries |
| Sparkle in a SwiftPM-only build | update layer sits behind `AppUpdateController`; Sparkle is wired in the packaged Xcode/`make-app.sh` build (see `ARCHITECTURE-DECISIONS.md`) |
| Signing/notarisation | app bundle built by `Scripts/make-app.sh` with hardened-runtime-ready Info.plist; no sandbox entitlement (the app must exec `brew`) |
