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

Clean local packaging artifacts:

```bash
pnpm package:clean
```

Optional packaging commands:

```bash
pnpm package:mac:x64
pnpm package:mac:universal
```

Current alpha builds are unsigned and not notarized. macOS may show a Gatekeeper warning for downloaded builds.

Before publishing an alpha build, run through `docs/alpha-checklist.md`.

## Notes

- The desktop app can run without Homebrew and will show Homebrew-not-found states.
- Mutating Homebrew actions must stay allowlisted and require explicit confirmation.
- Prefer adding shared data shapes to `packages/shared-types` before wiring new IPC.
