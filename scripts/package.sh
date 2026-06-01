#!/usr/bin/env bash
set -euo pipefail

pnpm --filter @brewwery/desktop build
pnpm --filter @brewwery/desktop exec electron-builder
