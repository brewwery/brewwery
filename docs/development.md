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

## Notes

- The desktop app can run without Homebrew and will show Homebrew-not-found states.
- Keep commands read-only until the action confirmation model is implemented.
- Prefer adding shared data shapes to `packages/shared-types` before wiring new IPC.
