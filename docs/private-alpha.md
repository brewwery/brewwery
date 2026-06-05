# Private Alpha

Private alpha target: `v0.6.0-alpha.1`.

## Build

Install dependencies and run checks:

```bash
pnpm install --frozen-lockfile
pnpm typecheck
pnpm lint
cargo test --manifest-path crates/brewwery-core/Cargo.toml
```

Build a local packaged `.app` without DMG creation:

```bash
pnpm package:clean
pnpm package:mac:dir
```

Build release artifacts:

```bash
pnpm package:clean
pnpm package:mac
```

Expected Apple Silicon artifacts:

```text
desktop/dist-packages/Brewwery-0.6.0-alpha.1-mac-arm64.dmg
desktop/dist-packages/Brewwery-0.6.0-alpha.1-mac-arm64.zip
desktop/dist-packages/mac-arm64/Brewwery.app
```

## Verify

Check bundle metadata:

```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "desktop/dist-packages/mac-arm64/Brewwery.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "desktop/dist-packages/mac-arm64/Brewwery.app/Contents/Info.plist"
```

Expected:

```text
0.6.0-alpha.1
com.brewwery.app
```

## Install

From DMG:

1. Open the DMG.
2. Drag `Brewwery.app` to `/Applications`.
3. Open `/Applications/Brewwery.app`.
4. Accept the unsigned app warning if testing a trusted private alpha build.

From local `.app`:

```bash
open "desktop/dist-packages/mac-arm64/Brewwery.app"
```

## Uninstall

Quit Brewwery first, then remove the app and local data:

```bash
rm -rf "/Applications/Brewwery.app"
rm -rf "$HOME/Applications/Brewwery.app"
rm -rf "desktop/dist-packages/mac-arm64/Brewwery.app"
rm -rf "$HOME/Library/Application Support/Brewwery"
rm -f "$HOME/Library/Preferences/com.brewwery.app.plist"
rm -rf "$HOME/Library/Saved Application State/com.brewwery.app.savedState"
```

This does not remove Homebrew or any installed Homebrew packages.

## GitHub Release Draft

Release tag:

```text
v0.6.0-alpha.1
```

Use `docs/release-notes/v0.6.0-alpha.1.md` as the draft release body.

Upload:

```text
Brewwery-0.6.0-alpha.1-mac-arm64.dmg
Brewwery-0.6.0-alpha.1-mac-arm64.zip
```

After `gh auth login`, create the draft release with:

```bash
gh release create v0.6.0-alpha.1 \
  --repo brewwery/brewwery \
  --draft \
  --prerelease \
  --title "Brewwery v0.6.0-alpha.1" \
  --notes-file docs/release-notes/v0.6.0-alpha.1.md \
  desktop/dist-packages/Brewwery-0.6.0-alpha.1-mac-arm64.dmg \
  desktop/dist-packages/Brewwery-0.6.0-alpha.1-mac-arm64.zip
```
