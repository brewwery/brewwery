# Changelog

## 1.1.1

Reliability fixes after the native-app audit. No new Homebrew commands.

### Fixed
- Packaging uses SwiftPM's actual product directory, not the obsolete `.build/apple` path.
  The packaged executable reports its compiled version/build without starting the app.
  Packaging verifies these against Info.plist, both architectures, resources, signatures and
  the linked executable's Mach-O UUIDs.
- Mutating operations reserve their slot before detection starts. Metadata updates, taps and
  pin/unpin share the coordinator; the runner independently rejects overlapping mutations.
- Buffered commands now support task cancellation, process-group termination, safety
  timeouts and explicit output-size errors. Path-validation probes also have a deadline.
- Streaming pipes no longer queue unlimited chunks. Slow consumers retain the terminal
  result and bounded output; split UTF-8 characters are preserved. Cancelling the caller
  waits for the process to exit before the operation slot is released.
- Package and service lists refresh after failed or cancelled operations as well as success,
  because Homebrew may have applied part of a change.
- Option-shaped package, cask, service, tap and search arguments are rejected before spawn.
- Detail drawers ignore stale package-info responses. Failed dependent checks show a retry
  state instead of incorrectly claiming that no packages depend on a formula; Packages now
  loads dependents too.
- Sparkle appcasts use a release-specific directory containing only the current DMG,
  with delta generation disabled. Old artifacts no longer acquire the newest release URL.
  A public-key verifier checks version/build, minimum OS, enclosure URL, byte length and
  the exact DMG's EdDSA signature before copying the feed to the website.
- Favorites/History read and write failures are visible and retryable. Corrupt JSON is backed
  up before replacement. JSON encoding, backup and atomic writes now run on a serial
  background queue, with rapid changes coalesced to the latest pending snapshot per store.
  Normal quit waits for persistence, warns if saving failed and is blocked during a mutation.

### Changed
- About and Settings credit [by Made Büro](https://github.com/madeburo).
- Bundles include the project MIT license and Sparkle's third-party license notices.
- README and security documentation describe the native app, Sparkle network activity and
  local data storage. The original copyright holder is unchanged.
- Native CI runs isolated tests and universal packaging verification without signing secrets
  or release publication. The release script runs the isolated test suite before packaging.
- `--qa-profile <name>` isolates Favorites, History and app preferences for packaged-app
  clean-install/restart checks without replacing the working profile. QA disables Sparkle
  and window-frame autosaving; it does not isolate or mutate Homebrew by itself.

Local verification and remaining release gates: [1.1.1 QA](docs/QA-1.1.1.md).

## 1.1.0

Ways to act on what Brewwery shows: report a problem without leaving the app, install a
Brewfile's missing packages, hold a formula at its version — and a German interface.

### Added
- Report a problem: a report you review first, then open as a GitHub issue or an email and
  send yourself. Nothing is sent automatically. It is available from Settings, the Help menu
  and the menu bar, and for failed operations and failed History entries.
- Brewfile: compare a Brewfile with this Mac and install only what is missing. Brewwery
  writes its own install list, so Homebrew never runs Ruby from a file someone sent you.
- Pin formulae: a pinned formula keeps its version, is skipped by Upgrade all and is not
  counted as outdated.
- A Go menu: ⌘1…⌘9 switch between the first nine pages.
- German interface. French, Spanish and Portuguese are planned for the next version.

### Changed
- Page headers move their buttons onto a second row when a translation makes them too wide.

### Fixed
- Settings › About no longer lists Apple Silicon as the only primary platform.

## 1.0.1

The outdated count had no home in the app: the Dock badge ran its own `brew outdated` every
half hour, so nothing in the window explained the number, and it kept the old count after an
upgrade until the next background check. There is now one list, and everything reads it.

### Added
- The count appears next to Updates in the sidebar, in the status bar and in the menu bar,
  so the number on the Dock is visible inside the app.
- The Updates page says where the count comes from and when it was last read.
- Settings gains a Dock section: the badge can be switched off.

### Changed
- The outdated list loads at launch with the installed packages, instead of 15 seconds later
  in a separate check.
- The background refresh is silent: it no longer flashes a loading state over a page that is
  being read, and a failed background check keeps the last good list instead of blanking it.
- Page headers keep their buttons at full width; a longer subtitle wraps instead.

### Fixed
- Upgrading from inside Brewwery clears the Dock badge immediately.
- A silent refresh at launch no longer leaves the Updates page showing "Loading updates...".

## 1.0.0

Brewwery is now a native macOS application. It replaces the Electron, React and Rust build of
0.9.7 with Swift 6, SwiftUI and AppKit, and keeps the same features, Homebrew commands and
validation rules.

### Changed
- Rebuilt natively: no Electron, Node or Rust runtime is shipped.
- The title bar is gone. Search and Settings sit in each page's header, next to that page's
  actions; the search field is compact and widens while you type.
- Packages, Casks and History filter from the header instead of a second search box.
- The first-launch overlay is removed; the "Homebrew not found" panel and Settings cover the
  same ground.
- The Dashboard no longer repeats the "Homebrew not found" error inside every card.
- Brewfiles can be opened with a file picker as well as by typing a path.
- The logo is rendered from the original vector artwork.

### Fixed
- Cancelling an operation now stops Homebrew's own child processes (`git`, `curl`) as well as
  `brew` itself.
- Formula names containing a `..` path segment are rejected before Homebrew is run.
- Validating a custom Homebrew path can no longer report a broken executable as valid.

### Requirements
- macOS 14 or later, Apple Silicon or Intel.
