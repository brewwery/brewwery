# Alpha Checklist

Use this checklist before publishing a public alpha build.

## Build

- `pnpm install --frozen-lockfile`
- `pnpm typecheck`
- `pnpm lint`
- `cargo test` in `crates/brewwery-core`
- `pnpm --filter @brewwery/desktop build`
- `pnpm package:mac:dir`
- `pnpm package:mac`

If local DMG creation fails with `hdiutil`, use `pnpm package:mac:dir` to test the packaged `.app` and let GitHub Actions create the DMG on a clean macOS runner.

## Packaged App

- Open `desktop/dist-packages/mac-arm64/Brewwery.app`.
- Confirm app name is Brewwery in the menu bar.
- Confirm dock icon and menu bar icon are Brewwery assets.
- Close the window with `Command+W`.
- Choose tray menu `Open Brewwery`.
- Confirm no main-process error appears.
- Choose tray menu `Check Updates`.
- Choose tray menu `Run Doctor`.
- Quit from tray menu.

## First Launch

- Delete local app data if a clean first-launch test is needed.
- Confirm onboarding appears.
- Confirm detected Homebrew version, prefix, architecture, and path.
- Confirm Homebrew-not-found copy is readable if Homebrew is unavailable.

## Settings

- Confirm detected Homebrew path is displayed.
- Validate `/opt/homebrew/bin/brew` on Apple Silicon.
- Save the custom path.
- Confirm Dashboard/Packages still load data.
- Reset the custom path.
- Export history JSON.
- Clear history.

## Core UX

- Dashboard loads without crashing.
- Packages handles large installed formula lists.
- Casks handles empty and non-empty states.
- Search has loading, empty, and error states.
- Package detail drawer opens from installed packages and discovery search.
- Install/uninstall/upgrade require confirmation.
- Progress output remains scrollable and does not freeze the UI.
- Raw output panels are readable.

## Safety

- No direct `ipcRenderer` usage outside preload.
- No generic shell command IPC exists.
- No `sudo`.
- No telemetry.
- No cloud sync.
- Mutating actions remain allowlisted and confirmed.

## Uninstall Local Alpha

Remove the local packaged app and Brewwery user data:

```bash
rm -rf "desktop/dist-packages/mac-arm64/Brewwery.app"
rm -rf "$HOME/Library/Application Support/Brewwery"
rm -f "$HOME/Library/Preferences/com.brewwery.app.plist"
rm -rf "$HOME/Library/Saved Application State/com.brewwery.app.savedState"
```
