# Release Candidate Checklist

Brewwery v0.9.1 Release Candidate checklist.

## Version And Metadata

- [ ] Workspace package version is `0.9.1`.
- [ ] Desktop package version is `0.9.1`.
- [ ] Shared types package version is `0.9.1`.
- [ ] Rust crate version is `0.9.1`.
- [ ] Cargo lock version is `0.9.1`.
- [ ] Generated napi wrapper expects `0.9.1`.
- [ ] `APP_VERSION` is `0.9.1`.
- [ ] `APP_CHANNEL` is `Release Candidate`.
- [ ] Bundle id is `com.brewwery.app`.
- [ ] Bundle metadata shows `0.9.1`.

## Build And Packaging

- [ ] `pnpm typecheck`
- [ ] `pnpm lint`
- [ ] `pnpm --filter @brewwery/desktop build`
- [ ] `pnpm package:mac:dir`
- [ ] `pnpm package:mac:zip`
- [ ] `pnpm release:verify`
- [ ] `pnpm package:mac:x64`
- [ ] `pnpm package:mac:universal`
- [ ] ZIP artifact opens after unzip.
- [ ] `.app` launches from `desktop/dist-packages/mac-arm64`.
- [ ] `.app` launches after moving to `/Applications`.
- [ ] DMG generation is verified locally or delegated to GitHub Actions if local `hdiutil` fails.

## Signing And Notarization

- [ ] Signing strategy decided.
- [ ] Unsigned fallback docs are current.
- [ ] Apple Developer Program status checked.
- [ ] Developer ID Application certificate available if signing.
- [ ] App-specific password or App Store Connect API key available if notarizing.
- [ ] CI secrets documented.
- [ ] `electron-builder` entitlements are present.

## Security Review

- [ ] No generic shell execution.
- [ ] No direct `ipcRenderer` in pages/components.
- [ ] Renderer uses `brewweryApi`.
- [ ] Rust allowlist remains intact.
- [ ] Streaming runner uses `shell: false`.
- [ ] Custom Homebrew path validation works.
- [ ] Mutating actions require confirmation.
- [ ] Cleanup run requires preview first.
- [ ] `brew update` requires confirmation.
- [ ] Invalid search query rejected in renderer and Rust.
- [ ] No sudo.
- [ ] No telemetry.
- [ ] No cloud sync.
- [ ] No paid/pro logic.
- [ ] No donations/support logic.

## UI QA

- [ ] Dark theme full pass.
- [ ] Light theme full pass.
- [ ] System theme full pass.
- [ ] Dashboard.
- [ ] Search.
- [ ] Packages.
- [ ] Casks.
- [ ] Updates.
- [ ] Services.
- [ ] Cleanup.
- [ ] Doctor.
- [ ] Brewfile.
- [ ] History.
- [ ] Settings.
- [ ] About.
- [ ] Onboarding.
- [ ] Progress output.
- [ ] Toasts.
- [ ] Dialogs.
- [ ] Error states.
- [ ] Empty states.

## Functional QA

- [ ] Homebrew detection.
- [ ] Custom Homebrew path.
- [ ] Search redis installed state.
- [ ] Invalid/Cyrillic search input.
- [ ] Package info drawer.
- [ ] Install formula.
- [ ] Uninstall formula.
- [ ] Upgrade one.
- [ ] Upgrade all.
- [ ] Refresh list.
- [ ] Check for updates.
- [ ] Services list.
- [ ] Service start/stop/restart.
- [ ] Cleanup preview.
- [ ] Cleanup run.
- [ ] Doctor run.
- [ ] Brewfile export.
- [ ] Brewfile read.
- [ ] History logging.
- [ ] History export JSON.
- [ ] Copy diagnostics.

## Docs

- [ ] README current.
- [ ] CHANGELOG current.
- [ ] Roadmap current.
- [ ] Security docs current.
- [ ] Development docs current.
- [ ] Known issues current.
- [ ] Release notes current.
- [ ] Screenshots current.
