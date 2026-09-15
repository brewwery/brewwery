# Changelog

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
