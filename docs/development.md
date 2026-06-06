# Development

## Requirements

- macOS
- Node.js 24
- pnpm 10
- Rust toolchain for `crates/brewwery-core`
- Homebrew for live package data

## Install

```bash
pnpm install
```

## Run

```bash
pnpm dev
```

## Build

```bash
pnpm build
```

Build only the Rust native core:

```bash
pnpm --filter @brewwery/brewwery-core build
```

## Package

Build an unsigned Apple Silicon DMG and ZIP:

```bash
pnpm package:mac
```

Artifacts are written to:

```text
desktop/dist-packages/
```

Build a packaged `.app` without creating a DMG:

```bash
pnpm package:mac:dir
```

Build a ZIP artifact without creating a DMG:

```bash
pnpm package:mac:zip
```

Clean local packaging artifacts:

```bash
pnpm package:clean
```

Run the private beta verification sequence:

```bash
pnpm beta:verify
```

Clean old local beta app/user data before a fresh install test:

```bash
pnpm beta:clean-install
```

Optional packaging commands:

```bash
pnpm package:mac:x64
pnpm package:mac:universal
```

Current beta builds are unsigned and not notarized. macOS may show a Gatekeeper warning for downloaded builds.

Before publishing a beta build, run through `docs/private-beta-test-report.md`.

Private beta release preparation lives in:

- `docs/private-beta.md`
- `docs/known-issues.md`
- `docs/private-beta-test-report.md`
- `docs/release-notes/v0.7.2-beta.3.md`

## Notes

- The desktop app can run without Homebrew and will show Homebrew-not-found states.
- Mutating Homebrew actions must stay allowlisted and require explicit confirmation.
- Prefer adding shared data shapes to `packages/shared-types` before wiring new IPC.
