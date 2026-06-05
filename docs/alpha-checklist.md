# Private Alpha Checklist

Use this checklist before publishing `v0.6.0-alpha.2`.

## Build

- `pnpm install --frozen-lockfile`
- `pnpm typecheck`
- `pnpm lint`
- `cargo test` in `crates/brewwery-core`
- `pnpm --filter @brewwery/desktop build`
- `pnpm package:mac:dir`
- `pnpm package:mac:zip`
- `pnpm package:mac`
- `pnpm alpha:verify`
- Confirm artifact names:
  - `Brewwery-0.6.0-alpha.2-mac-arm64.dmg`
  - `Brewwery-0.6.0-alpha.2-mac-arm64.zip`
- Confirm app version inside bundle is `0.6.0-alpha.2`.
- Confirm bundle id is `com.brewwery.app`.

If local DMG creation fails with `hdiutil`, use `pnpm package:mac:dir` to test the packaged `.app` and let GitHub Actions create the DMG on a clean macOS runner.

Use `pnpm package:mac:zip` plus `unzip -t` to verify the local ZIP artifact independently of DMG creation.

## Fresh Install

- Remove old local `.app`.
- Remove old `localStorage` data if a clean test is needed.
- Remove `settings.json` if a clean custom path test is needed.
- Open the DMG.
- Drag `Brewwery.app` into `/Applications`.
- Launch app from `/Applications`.
- Confirm app name is Brewwery in the menu bar.
- Confirm dock icon and menu bar icon are Brewwery assets.
- Confirm first launch onboarding appears.
- Confirm Homebrew auto-detection.
- Confirm Dashboard loads after first launch.
- Quit and reopen.
- Close the window with `Command+W`.
- Choose tray menu `Open Brewwery`.
- Confirm no main-process error appears.

## Homebrew Path QA

- `/opt/homebrew/bin/brew` works.
- `/usr/local/bin/brew` fallback does not break where available.
- Missing Homebrew state is readable.
- Invalid custom path is rejected.
- Valid custom path is accepted.
- Reset custom path returns to auto-detect.
- `brew --version` validation appears.
- Permission denied path is rejected.
- Non-executable file path is rejected.
- Directory instead of executable path is rejected.

## Pages

- Dashboard
- Dashboard last refreshed state
- Dashboard running-first service preview
- Packages
- Casks
- Search
- Updates
- Services
- Cleanup
- Doctor
- Brewfile
- History
- History failed-only filter
- Settings
- Settings Copy diagnostics

## Packages And Discovery

- Formulae list loads.
- Casks list loads.
- Search formulae works.
- Search casks works.
- Package detail drawer opens.
- Cask detail drawer opens.
- Package info loads.
- Cask info loads.
- Caveats display correctly.
- Raw JSON details are expandable.
- Install formula with confirmation.
- Install cask with confirmation.
- Uninstall formula with confirmation.
- Uninstall cask with confirmation.
- Install failure is handled.
- Uninstall failure is handled.
- Progress output works.
- History logs install/uninstall.
- Toast appears after operation.
- Package lists refresh after operation.

## Updates

- Updates page loads.
- Empty updates state.
- Outdated packages state.
- Upgrade one package confirmation.
- Upgrade all confirmation.
- Upgrade progress output.
- Upgrade failure handling.
- History logs upgrade.
- Toast appears after upgrade.
- Dashboard updates count refreshes.

## Maintenance

- Cleanup preview works.
- Parsed cleanup items display.
- Estimated size displays when available.
- Raw output expandable.
- Nothing to clean state.
- Cleanup run requires confirmation.
- Cleanup result summary.
- Cleanup failure handling.
- History logs cleanup.
- Toast appears after cleanup.
- Doctor diagnostics run.
- Brewfile export works.
- Brewfile read-by-path works.

## Tray And Shortcuts

- Tray menu opens.
- Open Brewwery works after close.
- Check Updates behaves safely.
- Run Doctor behaves safely.
- Open Terminal works.
- Quit works.
- `Command+K` Search.
- `Command+R` Refresh.
- `Command+,` Settings.
- `Command+W` Close.
- `Command+Q` Quit.
- Window restore works.
- No crash after closing/reopening window.

## Security Review

- No generic shell execution.
- No direct `ipcRenderer` in pages/components.
- Renderer uses `window.brewwery` API wrapper.
- Mutating actions require confirmation.
- Rust allowlist intact.
- Streaming runner uses `shell: false`.
- Custom path validation works.
- No `sudo`.
- No telemetry.
- No cloud sync.
- No paid/pro logic.
- No automatic cleanup.
- No automatic install/uninstall/upgrade.

## Release Draft

- Create GitHub release draft for `v0.6.0-alpha.2`.
- Use `docs/release-notes/v0.6.0-alpha.2.md` as release body.
- Upload DMG artifact.
- Upload ZIP artifact.
- Mark as prerelease.
