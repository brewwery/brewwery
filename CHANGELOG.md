# Changelog

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
