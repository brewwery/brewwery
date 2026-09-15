# Architecture Decisions

Every place where the native implementation departs from a line-by-line translation of
0.9.7, with the reason. Anything not listed here is a direct port.

---

## 1. Swift Package Manager, not a checked-in `.xcodeproj`

**Decision.** The app is a SwiftPM package; `Scripts/make-app.sh` assembles `Brewwery.app`.

**Why.** A package builds and tests from the command line (`swift build`, `swift test`),
opens directly in Xcode, and has no 30 000-line `project.pbxproj` to merge-conflict over. The
script produces a normal bundle that can be Developer ID-signed, notarised and shipped in a
DMG — the same output `electron-builder` produced.

**Trade-off.** Sparkle is not linked by the package (see §9).

---

## 2. Deployment target: macOS 14

**Decision.** `LSMinimumSystemVersion` 14.0 (Sonoma).

**Why.** The Observation framework (`@Observable`), which replaces the Zustand stores, is
macOS 14+; so are `onKeyPress`, `ScrollBounceBehavior` and `Layout` refinements the tables
rely on. Electron 43 supported macOS 11+, so this does narrow the supported range — but
Homebrew itself only supports the three most recent macOS releases, and every Mac that can run
a current Homebrew can run macOS 14. Sparkle 2 supports 10.13+, so it is not the constraint.

---

## 3. `posix_spawn` with a new process group, not `Process`

**Decision.** `ChildProcess` spawns Homebrew directly and makes the child a process-group
leader, so cancellation signals the whole group.

**Why.** Foundation's `Process` puts the child in Brewwery's own process group. `brew` forks
`git`, `curl` and `ruby`; the legacy Electron implementation called `child.kill()`, which
reached `brew` but not its children, so cancelling a download could leave work running. This
is a deliberate behavioural improvement over 0.9.7 and is covered by
`HomebrewRunnerTests.testCancellationTerminatesTheChildAndItsGrandchildren`.

---

## 4. Path-traversal segments are rejected in formula names

**Decision.** `HomebrewIdentifier.validateFormulaName` rejects any `..` path segment.

**Why.** The legacy rule allowed `..` because `.` and `/` are both legal identifier
characters, so `../../etc/passwd` passed validation and was handed to Homebrew verbatim. No
real formula or tap name contains a `..` segment, so refusing them costs nothing. Every other
validation rule is preserved exactly, including the differing 120/160 length limits between
the install and upgrade paths.

---

## 5. One `UserDefaults` owner for settings

**Decision.** All preferences live in `UserDefaults`; history and favourites live in JSON
files under `~/Library/Application Support/Brewwery/`.

**Why.** 0.9.7 split the same settings across renderer `localStorage` and a main-process
`settings.json` that held only `homebrewPath`, and the Settings page had to copy one into the
other on mount. One owner removes that sync step. Semantics are unchanged: the custom
Homebrew path is validated before it is stored and dropped at launch if it stops validating.

---

## 6. One instance of each feature model

**Decision.** `AppEnvironment` builds one `SystemModel`, `PackageLibrary`, `UpdatesModel` and
so on, shared by every screen.

**Why.** The legacy hooks were instantiated per page, so opening the Dashboard ran five
Homebrew queries that other pages had already run, and two pages could disagree about what was
installed. The user-visible data is the same; there are simply fewer `brew` invocations.

---

## 7. An explicit shell instead of `NavigationSplitView`

**Decision.** `RootView` composes the title bar, sidebar, content and status bar directly.

**Why.** Brewwery's sidebar is a fixed 260 pt, flat-coloured, non-collapsible panel with a
wordmark on top and a status card pinned to the bottom. `NavigationSplitView` would add a
translucent material, a collapse control and a resize handle the product never had —
a redesign, not a port. The sidebar's navigation scrolls, which the legacy `flex-1` column
could not: with 15 entries the legacy sidebar overflowed its own column at the default window
height and simply clipped History and Settings.

---

## 8. ⌘, opens the in-app Settings page, not a `Settings` scene

**Decision.** The Settings **page** is kept, and ⌘, selects it, exactly as the legacy
`sendShortcut("settings")` did.

**Why.** This is the one place the brief's suggestion (use SwiftUI `Settings`) and its
overriding rule (reproduce the existing product, do not redesign) point in different
directions. Brewwery's Settings page is not a preferences panel: it validates a Homebrew
executable, runs `brew update`, exports the operation history and shows the About block with a
diagnostics report. Splitting the preferences out would leave a half-empty page and move
familiar controls. Parity won; this is the deliberate deviation from §29 of the brief.

---

## 9. Sparkle, started only inside the signed bundle

**Decision.** Sparkle 2 is a SwiftPM dependency. `SparkleUpdateDriver` wraps
`SPUStandardUpdaterController` behind the `AppUpdateDriver` protocol and is created only when
the main bundle is Brewwery's and carries both `SUFeedURL` and `SUPublicEDKey`.

**Why.** Under `swift run` and in tests the main bundle belongs to something else, and starting
Sparkle there only raises a configuration alert. The protocol keeps the app testable without
the framework. "Include pre-release versions" maps to Sparkle's `beta` channel through
`allowedChannels(for:)`. Application updates stay completely separate from Homebrew package
updates — the two are unrelated systems and the UI never conflates them.

**Keys.** The EdDSA private key lives in the login keychain under the Sparkle account
`brewwery`; the public key is in `Packaging/Info.plist`. Losing the private key means no update
can ever be delivered to installed copies, so it must be backed up
(`generate_keys --account brewwery -x brewwery-sparkle.key`).

---

## 10. Confirmations are a custom sheet, not `.confirmationDialog`

**Decision.** `ConfirmationDialogView` reproduces the legacy dialog, with native keyboard
behaviour (Escape cancels, Return confirms, and the confirm button is the default button).

**Why.** Showing the exact command — monospaced, in full — before running it is part of the
product's contract with the user. A system alert's message is plain text and would flatten
`brew uninstall --cask iterm2` into the surrounding prose.

---

## 11. System font instead of Inter

**Decision.** San Francisco at the same sizes and weights.

**Why.** The legacy stack was `Inter, ui-sans-serif, system-ui, -apple-system, …`. Inter was
never bundled, so on macOS the stack already resolved to the system font unless the user
happened to have Inter installed.

---

## 12. Brewfile reading offers a file picker

**Decision.** The typed absolute-path field is kept, with a "Choose…" button next to it.

**Why.** The legacy page only accepted a typed path. The field still works exactly as before
and the same validation applies to both routes; the panel is an addition to that one control,
not a replacement.

---

## 13. Logos are rasterised from the original SVG, not from the bundled PNG

**Decision.** `Scripts/render-svg.swift` renders `Packaging/Logo/*.svg` to transparent 2× PNGs through
WebKit; the results are checked in under `Sources/Brewwery/Resources`.

**Why.** The legacy `desktop/assets` directory ships the wordmark both as SVG and as a PNG
flattened onto a white background. Deriving the app's artwork from that PNG loses the mug's
handle and the cut-outs in the foam. Rendering the vector source with the same engine Electron
used keeps the mark identical to 0.9.7 at any size, and the dark and light variants come from
the two SVGs the brand actually defines rather than from a recolouring heuristic.

---

## 14. `brew list --json=v2` fallback is preserved

**Decision.** `run(_:fallback:)` retries with `--versions --json` only when the failure text
contains `needless argument`.

**Why.** Homebrew 6 rejects `--json=v2` for `brew list`, which is exactly the case the legacy
fallback existed for — and exactly what the development machine hits. The fallback payload
carries no `desc` or `full_name`, which is why descriptions are blank on such installs in both
implementations.

---

## 15. No title bar, and no first-launch overlay

**Decision.** Requested by the product owner after reviewing the port, so this is a change to
the product rather than a porting choice.

* The title bar is gone. The window opens with a hidden one and the shell now starts with an
  empty 28 pt strip that clears the traffic lights and drags the window.
* The app name is no longer repeated in the chrome — the wordmark in the sidebar already says
  it, and the window's own title carries it for the Window menu and Mission Control.
* The global search field and the Settings button moved down into each page's header, grouped
  to the right of that page's own actions and separated from them by a hairline. They sit in
  `PageHeader`, so all fifteen screens get them in the same place for free.
* The search field is deliberately short — 200 pt at rest — and widens to 320 pt while it has
  focus, so a long package name stays readable without the control dominating the header.
* Return moves to the Search page rather than every keystroke doing so. Switching pages
  rebuilds the header and would pull focus out of the field mid-word; once the Search page is
  open the field is no longer rebuilt, so results do update live as the user keeps typing.
  ⌘K still jumps to Search and focuses the field.
* The first-launch onboarding overlay is removed, along with the `firstLaunchComplete`
  preference that gated it. Nothing is lost: when Homebrew is missing, every feature page
  already shows the "Homebrew not found" panel with the paths that were checked, and Settings
  offers the same detection details plus the custom-path field the overlay pointed at.

---

## 16. Packaged images come from `Contents/Resources`, never `Bundle.module`

**Decision.** `Scripts/make-app.sh` copies the PNGs into `Contents/Resources`, and `AppAssets`
reads them from the main bundle. SwiftPM's `Bundle.module` is only consulted when the binary
runs unpackaged.

**Why.** The accessor SwiftPM generates looks for its resource bundle beside the `.app` — where
a file would break the code signature — or at the absolute build path of the machine that
compiled it, and calls `fatalError` if neither exists. A build that worked here would have
crashed at launch on every other Mac.

---

## 17. Tests never reach the real Homebrew unless asked

**Decision.** `FakeBrew.makeClient()` builds a detector with no standard locations and a `PATH`
containing only the double. The app test harness stores the double as the custom path and
asserts, before every test, that detection resolves to it. Tests against the real Homebrew live
in `BrewweryLiveTests` and skip unless `BREWWERY_LIVE=1`.

**Why.** An early version of the rendering tests called `AppEnvironment.prepare()`, which
clears the custom path when none is stored, and silently fell back to `/opt/homebrew/bin/brew`.
Nothing changed on the machine that time only because the package it asked to upgrade was
already current. The double must be unreachable-by-construction, not by convention.

---

## 18. Accessibility is guaranteed structurally

**Decision.** Every icon-only control is an `IconButton`, whose accessible name is a required
argument that also becomes its tooltip. `AccessibilityLintTests` fails if a hand-written
icon-only `Button` appears anywhere in the app.

**Why.** SwiftUI publishes its accessibility tree only to an assistive client, and reading it
from a test needs the Accessibility privacy permission — which a test run should not demand.
Unlabeled icon buttons are the realistic VoiceOver regression, and the type system can rule
them out. A manual VoiceOver pass is still worth doing before a release.
