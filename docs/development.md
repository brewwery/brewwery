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

Run the Launch Candidate verification sequence:

```bash
pnpm release:verify
```

Clean old local app/user data before a fresh install test:

```bash
pnpm beta:clean-install
```

Optional packaging commands:

```bash
pnpm package:mac:x64
pnpm package:mac:universal
```

Current Launch Candidate builds are unsigned and not notarized. macOS may show a Gatekeeper warning for downloaded builds.

Before publishing a Launch Candidate build, run through `docs/launch-candidate-checklist.md`.

Launch Candidate release preparation lives in:

- `docs/known-issues.md`
- `docs/launch-candidate-checklist.md`
- `docs/release-notes/v0.8.2.md`

## Notes

- The desktop app can run without Homebrew and will show Homebrew-not-found states.
- Mutating Homebrew actions must stay allowlisted and require explicit confirmation.
- Prefer adding shared data shapes to `packages/shared-types` before wiring new IPC.
