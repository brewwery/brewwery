# Brewwery

Homebrew, without the terminal. A native macOS Homebrew GUI built with Swift 6, SwiftUI and
AppKit. No Electron, Node, Rust runtime, WebView or JavaScript bridge.

**1.1.1** is a reliability release: verified packaging, serialized Homebrew mutations,
bounded process output, cancellable reads and background JSON persistence with visible
local-storage failures.
See [CHANGELOG](CHANGELOG.md) for the complete release history.

[by Made Büro](https://github.com/madeburo) · [Website](https://www.brewwery.com) ·
[Releases](https://github.com/brewwery/brewwery/releases) · [Documentation](https://docs.brewwery.com)

## Features

* Packages and casks: search, inspect, install, uninstall and upgrade with confirmation.
* Discover collections, local Favorites, leaves, installed dependents and formula pinning.
* Services, taps, cleanup preview, Doctor and local operation History with JSON export.
* Read/export Brewfiles and install missing supported entries from a validated install list.
* Live progress and cancellation, Dock update count, dark/light/system themes and English/German.
* Report a problem with a preview you review before opening an email or GitHub issue.

## Install

Download a published DMG from [GitHub Releases](https://github.com/brewwery/brewwery/releases),
open it, and move Brewwery to Applications. Homebrew must already be installed; Brewwery
does not install it automatically. Custom executable paths can be validated in Settings.

The local build below is ad-hoc signed, **not notarized**. It is not a public-release artifact.
Do not disable Gatekeeper globally. Only approve a downloaded app after verifying its source.

## Requirements

* macOS 14 or later, Apple Silicon or Intel (see `docs/ARCHITECTURE-DECISIONS.md` §2)
* Xcode 16 or later / a Swift 6 toolchain
* Homebrew, for the app to manage — Apple Silicon and Intel prefixes are both supported

## Build and run

```bash
swift build          # compile
swift run Brewwery   # run without packaging
BREWWERY_LIVE=0 swift test --skip BrewweryLiveTests  # isolated tests, no real Homebrew
```

Build a local application bundle (ad-hoc signed, launchable, not distributable):

```bash
Scripts/make-app.sh
bash Scripts/verify-app.sh dist/Brewwery.app
open dist/Brewwery.app
```

For an isolated first-launch/restart check of that exact bundle:

```bash
dist/Brewwery.app/Contents/MacOS/Brewwery --qa-profile clean-111 -ApplePersistenceIgnoreState YES
```

Use a new profile name for each clean-install pass. QA profiles keep Favorites/History in
`~/Library/Application Support/Brewwery QA/<name>/` and preferences in
`com.brewwery.qa.<name>`. The window title identifies the QA profile, window-frame autosaving
is disabled and Sparkle is not started. Quit and repeat the command with the same name to
check persistence. Ordinary launches still use your normal profile. QA profiles do **not**
sandbox Homebrew: do not run install, uninstall or other mutations against your working
installation. They also do not replace a fresh macOS account or Gatekeeper test.

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

This first runs the isolated test suite, builds a universal app, signs it inside-out with the hardened runtime, notarises and
staples it, wraps it in a signed DMG, notarises and staples that, and regenerates
`dist/appcast/appcast.xml`. Then:

The appcast is generated from the current DMG only, with embedded release notes and no
delta files. `Scripts/verify-appcast.swift` checks its version/build, minimum OS, download
URL, byte length and EdDSA signature against the bundle's public key. Then:

1. upload `dist/appcast/Brewwery-<version>.dmg` to the GitHub release for the matching source tag;
2. download that public file and compare its SHA-256 with the signed local artifact;
3. deploy the matching website version, DMG and appcast together, publishing the feed at
   the `SUFeedURL` in `Packaging/Info.plist` only after the enclosure is reachable;
4. check the public feed and download, then separately test Sparkle installation/relaunch.

Pass `--site-public "<website>/public"` to also copy the DMG to `download/brewwery.dmg` and the
appcast to `appcast.xml` in the website, ready to deploy.

Website and documentation screenshots come from the app itself, in demo mode against a scripted
Homebrew, so they never show a real machine's data:

```bash
Scripts/screenshots.sh dist/screenshots
```

Sparkle signs updates with the EdDSA key stored in the login keychain under the account
`brewwery`. Keep a secure offline backup outside the checkout; never commit or upload keys.
Packaging verification does not replace clean-install, Intel hardware or notarization QA.
See [the release checklist](docs/RELEASE-CHECKLIST.md).

Native 1.x users update through **Settings > Application updates > Check for updates now**.
Finish Homebrew operations before installing and relaunching. Settings, Favorites and
History keep their existing locations. Electron 0.9.x has no Sparkle updater and requires
the DMG; its app data is not automatically migrated.

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

* no generic shell execution, no `sudo`, no telemetry or cloud sync in the desktop app;
* mutating operations are allowlisted and confirmation-gated, cleanup additionally
  preview-gated;
* package, cask, service and tap names, search queries and Brewfile paths are validated;
  option-shaped names and traversal segments are rejected;
* external links open only against the allowlist in `ExternalLinkPolicy`;
* only `HOMEBREW_NO_AUTO_UPDATE` and `HOMEBREW_NO_ANALYTICS` are injected into Homebrew's
  environment;
* one mutating operation at a time, including metadata, tap and pin/unpin operations;
* cancellation terminates the process group; reads have a 60-second safety timeout, short
  mutations 5 minutes and path probes 10 seconds. Streaming operations have their own limits;
* buffered stdout/stderr are capped at 16 MB per pipe with an explicit error, not silently
  truncated JSON. Live output and pending UI events are bounded.

**Network activity:** Homebrew downloads metadata and packages. Configured app bundles use
Sparkle to check the Brewwery appcast and download app updates; automatic checks can be
disabled in Settings. Opening homepages, the website, GitHub or email is user-initiated.
The website has its own analytics policy, separate from the desktop application.

**Local data:** settings use UserDefaults; Favorites and History are JSON files under
`~/Library/Application Support/Brewwery/`. They are not uploaded. JSON encoding, recovery
copies and atomic writes use a serial utility queue; rapid changes keep only the latest
pending snapshot per store. Normal quit waits for pending writes. Write errors retain
changes in memory and show Retry; quitting after a failed save requires an explicit choice
to discard them. Unreadable JSON is copied to an `.unreadable-<UUID>.bak` file before a later
save replaces it. Force-quit or power loss can still lose changes not yet written. Initial
loads and manual History export remain synchronous. Review diagnostics before sharing them.

## Credits and License

Brewwery is maintained by [Made Büro](https://github.com/madeburo). Source is available under
the [MIT license](LICENSE); its existing copyright notice remains unchanged.
[Sparkle](https://sparkle-project.org/) provides app updates. The packaged About panel links
to both the project license and Sparkle's bundled third-party notices.

## Documentation

* [1.1.1 local QA](docs/QA-1.1.1.md) - verified results and remaining manual checks
* [Native release checklist](docs/RELEASE-CHECKLIST.md) - packaging and publication gates
* `docs/MIGRATION-AUDIT.md` — the Phase 0 audit of the legacy app
* `docs/LEGACY-TO-NATIVE-MAP.md` — every legacy module and its replacement
* `docs/ARCHITECTURE-DECISIONS.md` — every deliberate departure, with reasons
