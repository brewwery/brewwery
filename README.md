# Brewwery

Brewwery rebuilt as a fully native macOS application in Swift 6, SwiftUI, AppKit and
Foundation. No Electron, no Node, no Rust, no WebView, no JavaScript bridge.

This is the same product as `apps/` (Brewwery 0.9.7), not a new one: the same fifteen screens,
the same Homebrew commands, the same validation rules, the same copy, the same palette.

## Requirements

* macOS 14 or later, Apple Silicon or Intel (see `docs/ARCHITECTURE-DECISIONS.md` §2)
* Xcode 16 or later / a Swift 6 toolchain
* Homebrew, for the app to manage — Apple Silicon and Intel prefixes are both supported

## Build and run

```bash
swift build          # compile
swift run Brewwery   # run without packaging
swift test           # core, app and rendering tests — nothing touches the real Homebrew
```

Build a local application bundle (ad-hoc signed, launchable, not distributable):

```bash
Scripts/make-app.sh
open dist/Brewwery.app
```

## Tests

| Suite | What it covers | Real Homebrew |
| --- | --- | --- |
| `BrewweryCoreTests` | parsers (legacy Rust fixtures), validation, detection, streaming, process-group cancellation | no — a scripted `brew` double |
| `BrewweryAppTests` | operation history and toasts, search debounce, table navigation and column layout, every page rendered in both themes, icon-button accessibility lint | no |
| `BrewweryLiveTests` | every read, install/uninstall, cancelling a real download, service start/stop, tap add/remove, custom path, offline failure | **yes**, opt-in |

Run the live suite deliberately — it installs and removes `hello`, `go` and `etcd`, and
adds and removes the `teamookla/speedtest` tap:

```bash
BREWWERY_LIVE=1 swift test --filter BrewweryLiveTests
BREWWERY_LIVE=1 BREWWERY_LIVE_UPGRADE=<outdated-formula> swift test --filter testUpgradeOneOutdatedFormula
```

Review every screen after a UI change:

```bash
BREWWERY_SNAPSHOT_DIR=/tmp/brewwery-snapshots swift test --filter RenderingTests
```

## Releasing

```bash
Scripts/release.sh --sign "Developer ID Application: …"   # notarises with the "Brewwery" notarytool profile
```

This builds a universal app, signs it inside-out with the hardened runtime, notarises and
staples it, wraps it in a signed DMG, notarises and staples that, and regenerates
`dist/appcast/appcast.xml`. Then:

1. upload `dist/appcast/Brewwery-<version>.dmg` to the GitHub release for the tag;
2. publish `dist/appcast/appcast.xml` at the `SUFeedURL` in `Packaging/Info.plist`.

Pass `--site-public "<website>/public"` to also copy the DMG to `download/brewwery.dmg` and the
appcast to `appcast.xml` in the website, ready to deploy.

Website and documentation screenshots come from the app itself, in demo mode against a scripted
Homebrew, so they never show a real machine's data:

```bash
Scripts/screenshots.sh dist/screenshots
```

Sparkle signs updates with the EdDSA key stored in the login keychain under the account
`brewwery`. Back it up — without it no update can reach installed copies:

```bash
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account brewwery -x brewwery-sparkle.key
```

## Brand assets

The wordmark and the menu-bar icon are authored as SVG in `Packaging/Logo/`. macOS cannot load
SVG into `NSImage` outside an asset catalog, so they are rasterised once into
`Sources/Brewwery/Resources`:

```bash
LOGO=Packaging/Logo
swift Scripts/render-svg.swift "$LOGO/Brewwery-Logotype.svg" Sources/Brewwery/Resources/WordmarkDark.png  962 305
swift Scripts/render-svg.swift "$LOGO/Brewwery.svg"          Sources/Brewwery/Resources/WordmarkLight.png 962 305
swift Scripts/render-svg.swift "$LOGO/menu-bar-icon.svg"     Sources/Brewwery/Resources/MenuBarIcon.png   256 256
```

The renderer draws through WebKit — the same engine the Electron build used — so the output is
identical to 0.9.7, at 2× with a real alpha channel. Re-run it whenever a logo changes.

## Layout

```text
Sources/
├── BrewweryCore/          # no UI — testable on its own
│   ├── Homebrew/          # detection, typed commands, validation, runner, coordinator
│   ├── Models/            # Formula, Cask, OutdatedPackage, BrewService, …
│   ├── Parsers/           # ports of the Rust parsers, fixture-tested
│   ├── Persistence/       # settings, history, favourites
│   ├── Errors/  Logging/  Utilities/
│
└── Brewwery/              # the app
    ├── App/               # entry point, delegate, environment, commands, operations
    ├── DesignSystem/      # palette, metrics, components, tables, state panels
    ├── Features/          # Shell (sidebar, status bar, global search) + one per screen
    ├── Models/            # @Observable feature models
    └── Catalogs/          # the bundled Discover / command / Brewfile data

Tests/                     # core, app, live and shared test-support targets
Packaging/                 # Info.plist and entitlements
Scripts/make-app.sh        # builds and optionally signs Brewwery.app
docs/                      # audit, legacy→native map, architecture decisions
```

## How a command reaches Homebrew

```text
SwiftUI view
  → feature model (@Observable, @MainActor)
    → HomebrewClient (actor)
      → HomebrewCommand — validates its arguments, produces argv
        → HomebrewRunner (actor)
          → ChildProcess — posix_spawn, own process group, no shell
            → brew
```

The UI cannot construct a command line. `HomebrewCommand` is a closed enum with no case that
accepts free-form arguments, every dynamic component is validated before argv exists, and no
shell is involved at any point. Cancelling an operation signals the child's whole process
group, so `brew`'s own `git` and `curl` children go with it.

## Security

The rules from `apps/docs/security.md` are preserved and, in two places, tightened:

* no generic shell execution, no `sudo`, no telemetry, no network calls of Brewwery's own;
* mutating operations are allowlisted and confirmation-gated, cleanup additionally
  preview-gated;
* package, cask, service and tap names, search queries and Brewfile paths are all validated
  against the same character rules as 0.9.7;
* external links open only against the allowlist in `ExternalLinkPolicy`;
* only `HOMEBREW_NO_AUTO_UPDATE` and `HOMEBREW_NO_ANALYTICS` are injected into Homebrew's
  environment;
* one mutating operation at a time, with the same per-operation safety timeouts;
* **new:** cancellation terminates the whole process group, and `..` path segments are
  rejected in formula identifiers.

## Documentation

* `docs/MIGRATION-AUDIT.md` — the Phase 0 audit of the legacy app
* `docs/LEGACY-TO-NATIVE-MAP.md` — every legacy module and its replacement
* `docs/ARCHITECTURE-DECISIONS.md` — every deliberate departure, with reasons
