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

Run the Release Candidate verification sequence:

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

Apple Silicon is the recommended v1.0 target. x64 and universal builds are validation targets for v0.9.0, but Intel runtime testing still requires an Intel Mac or dedicated runner.

On this machine, x64 and universal packaging currently fail before Electron packaging because the Rust `x86_64-apple-darwin` target is not installed. A machine with `rustup target add x86_64-apple-darwin` or a dedicated Intel/universal CI runner is required to complete that validation.

Current Release Candidate builds are unsigned and not notarized. macOS may show a Gatekeeper warning for downloaded builds. See `docs/signing-notarization.md` for the v1.0 signing plan, entitlements, and required CI secrets.

Before publishing a Release Candidate build, run through `docs/release-candidate-checklist.md`.

Release Candidate release preparation lives in:

- `docs/known-issues.md`
- `docs/release-candidate-checklist.md`
- `docs/release-notes/v0.9.0.md`
- `docs/signing-notarization.md`

## Notes

- The desktop app can run without Homebrew and will show Homebrew-not-found states.
- Mutating Homebrew actions must stay allowlisted and require explicit confirmation.
- Prefer adding shared data shapes to `packages/shared-types` before wiring new IPC.
