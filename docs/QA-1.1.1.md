# Brewwery 1.1.1 QA

Verified on 2026-10-18 with Apple Swift 6.4 on Apple Silicon, macOS 27.0.1.
The sections below distinguish local-profile QA, the initial candidate and final signed
distribution checks. Feed verification does not imply an installed Sparkle update test.

## Passed

- 218 isolated tests: 158 core tests and 60 app tests, zero failures.
  `BREWWERY_LIVE=0 swift test --skip BrewweryLiveTests` used a separate scratch directory.
  No real Homebrew install, uninstall, upgrade, tap or service mutation was run.
- Tests cover early operation reservations, buffered/streaming mutual exclusion, caller
  cancellation, child-process groups, timeouts, large stdout/stderr, slow consumers and
  split UTF-8 output. Partial failures and cancelled calling tasks still refresh
  installed-package state.
- Persistence tests cover visible read/write failures, corrupt-file backup and retry.
  Detail-drawer tests cover failed dependent checks and stale package-info responses.
- Background persistence tests cover write ordering, coalescing, a stale write failure,
  cancellation of a flush waiter, 500 rapid favorite changes and 140 large History entries
  restoring only the newest 100. Encoding an 8 MB payload stayed off the main thread and
  allowed more than five main-actor heartbeats during an injected 150 ms encoding delay.
  This is a concurrency regression test, not a real-disk performance benchmark.
- Rendering tests generated every page in both themes. Settings/About credit and the
  storage-error banner were additionally inspected in dark and light snapshots. These
  are test-host renders, not a manual packaged-app interaction or VoiceOver pass.
- `bash Scripts/make-app.sh --output dist/v1.1.1-local` completed. The script obtained the
  actual product directory from SwiftPM instead of reusing `.build/apple`.
- Packaged executable and bundle metadata both report version `1.1.1`, build `111`,
  bundle ID `com.brewwery.app`; the compiled channel is `Stable`.
- Main executable and embedded Sparkle contain `arm64` and `x86_64`. Both main executable
  slices declare macOS 14.0 as their minimum OS. Images, English/German localizations and
  project/Sparkle licenses are present; the ad-hoc code signature passes strict verification.
- A ZIP was extracted into a fresh temporary directory and passed `verify-app.sh`, including
  executable UUID comparison with the newly linked binary. Comparing against the obsolete
  `.build/apple` binary correctly failed verification. A temporary bundle with a deliberately
  mismatched plist version was also rejected before signature validation.

## Packaged clean profile and restart

- Extracted the final ZIP into a new temporary directory and copied it to
  `/Applications/Brewwery QA 1.1.1.app`, leaving `/Applications/Brewwery.app` in place.
- Launched the exact copied executable with `--qa-profile clean-111-final-20261018` and
  `-ApplePersistenceIgnoreState YES`. Neither its JSON directory nor its preferences suite
  existed beforehand. Favorites and History were empty in the UI.
- Homebrew detection and read-only lists loaded. Settings/About and the status bar showed
  `1.1.1`; Settings showed `Stable` and `by Made Büro` with the expected GitHub destination.
- Selected Light, ran read-only `brew doctor`, then added `git` to Favorites immediately
  before pressing Command-Q. The process exited normally with status 0.
- Reopened the same packaged executable/profile. Favorites contained `git`, History retained
  the successful Doctor entry (including its diagnostics), and Light remained selected.
  Quit normally again with status 0. An earlier pass also retained `git` and `jq` across
  two quit/reopen cycles.
- No real install, uninstall, upgrade, tap, service change or cleanup was performed.
  QA profiles disable Sparkle, but do not sandbox the underlying Homebrew installation.
- The working app executable and working Favorites/History retained their original SHA-256
  hashes. An early QA pass touched shared AppKit preferences; QA window-frame autosaving
  was then disabled. The final clean/restart pass left the main preferences file's hash
  unchanged. The working theme remained dark while the QA suite stored light. No preference
  rollback or user-data deletion was performed.

This proves a clean **app-data profile** and restart on this Apple Silicon Mac, not a clean
macOS account, quarantine/Gatekeeper acceptance, Intel runtime or signed-distribution test.
The isolated QA copy and profiles remain available; the QA process is closed.

## Local artifacts

- `dist/v1.1.1-local/Brewwery.app`: approximately 17 MiB on disk.
- `dist/v1.1.1-local/Brewwery-1.1.1-local-universal.zip`: 6,185,659 bytes (about 5.9 MiB).
- ZIP SHA-256: `95bf18f02aac894c60964914e782a425e42b4930ba91109a9b3284d886370617`.

The app in the ZIP above is ad-hoc signed, not Developer ID signed or notarized. The existing
application in `/Applications` was not replaced during that QA pass.

## Initial signed local DMG candidate (superseded)

Prepared on 2026-10-18, separately from the ad-hoc ZIP above:

- `dist/v1.1.1-signed-local/Brewwery-1.1.1.dmg`: 6,875,008 bytes (about 6.56 MiB).
- SHA-256: `6fa58e7b4a7653314eaf2bdf35680c3878bb92459fc2a26a2979af3728f94e24`.
- The app and DMG are Developer ID signed. Strict signature checks passed with system
  keychain access. An initial sandboxed DMG signature check failed; the same unchanged file
  passed outside that sandbox.
- `hdiutil create` completed using APFS and UDZO; `hdiutil verify` passed. This host's tool
  reports deprecation warnings, not the older APFS creation failure.
- Mounted read-only, the app passed `verify-app.sh`: version 1.1.1, build 111, Stable,
  `com.brewwery.app`, both architectures, resources and signatures. The Applications link
  resolves to `/Applications`. The image was unmounted afterwards.
- A local appcast candidate contains only the full 1.1.1 DMG, embedded notes and no deltas.
  Its URL, version/build, minimum OS, exact byte length and EdDSA signature passed the
  public-key verifier. Sixteen synthetic appcast regression checks also passed, including
  wrong metadata, invalid signature, equal-length tampering, wrong key and stale URL.
- The installed 1.1.0 bundle advertises build 110, the same public key and the same feed URL.
  This checks update metadata compatibility, not an installed Sparkle update/relaunch.
- Website and docs content now describe 1.1.1 locally. Both production builds passed, and
  twelve local HTTP/content checks passed. The website's public DMG/appcast were deliberately
  left unchanged; do not deploy the new version content without its release artifact.

This initial candidate was not notarized or published. Sending artifacts to Apple initially
waited for explicit user approval. Approval was then received and the final release below
was rebuilt, notarized and signed for Sparkle again. Do not publish this earlier candidate.

## Final signed distribution

Verified on 2026-10-18 after explicit approval to notarize and publish:

- `Scripts/release.sh` completed, including a fresh run of all 218 isolated tests and
  16 offline appcast regression checks.
- Final DMG: `dist/appcast/Brewwery-1.1.1.dmg`, 6,876,575 bytes (about 6.56 MiB).
- SHA-256: `f3666a7a059540cb07a24c52342d22a2a9c80e9e4e903afab74de500111550d1`.
- A clean GitHub checkout exposed an unused empty test-resource declaration and SwiftUI
  overloads unavailable in the Xcode 16.4 SDK. The declaration was removed; localized
  labels now use `Text`, and AppKit image assets are explicitly main-actor isolated.
  All 218 tests and the 16 appcast checks passed again after these changes. The final app
  and DMG were rebuilt and notarized again; the earlier signed candidate was not published.
- Apple accepted the final app submission `23b7ac73-4d38-4f93-8331-ff4c97e40f19` and DMG
  submission `ead8c61d-01b7-438b-bf7c-f4d4d15f093d`. Both tickets were stapled and validated.
- Gatekeeper accepted the app and DMG as `Notarized Developer ID`.
- The final DMG mounted read-only. Its app passed `verify-app.sh`, including Mach-O UUID
  comparison with the release executable, version 1.1.1/build 111/Stable, both architectures,
  resources and signatures. The contained app's ticket also validated and Gatekeeper
  accepted it. The Applications symlink resolves correctly.
- The regenerated appcast verifies against these final bytes and the bundle's public key.
  It advertises only build 111, macOS 14+, the version-specific GitHub DMG and embedded notes,
  with no delta entries. This supersedes the initial candidate's size/hash/signature.
- The installed 1.1.0 bundle has build 110 and the same Sparkle public key/feed URL.
  The working application and its data were not replaced during artifact verification.
- [Native CI run 39155925228](https://github.com/brewwery/brewwery/actions/runs/39155925228)
  passed on commit `e5f2c03` with macOS 26 / Xcode 26.6: isolated tests, all 16 appcast
  checks, universal packaging, headless bundle verification and QA ZIP artifact upload.
  Xcode 16.4 also passed the isolated tests; its universal build graph failed, so the
  packaging toolchain requirement is now documented separately from the minimum runtime OS.
- The final website/docs commits passed production builds and 25 HTTP/content checks in
  separate Hetzner staging directories, including DMG SHA-256, appcast metadata, localized
  routes, static assets and documentation. Production promotion is recorded separately below.

## Not yet verified

- A fresh macOS account and native About-panel link interaction. Settings/About text and
  the link destination were inspected; no external page or license link was opened.
- Real Intel hardware and macOS 14 compatibility. The local toolchain emits an x86_64
  deprecation warning for its macOS 27 host; universal linking is not runtime proof.
- Real Homebrew mutations, offline/permission errors against a real installation,
  keyboard-only navigation and VoiceOver.
- Public DMG delivery and a Sparkle install/relaunch from a previous installed release.
  Local notarization and signature checks alone do not prove either delivery step.

See [the release checklist](RELEASE-CHECKLIST.md) for those manual gates and the remaining
engineering boundaries, including synchronous initial JSON reads/manual History export and
the per-runner mutation lock. Normal quit flushes background writes; force-quit/power loss
can still discard an unwritten snapshot.
