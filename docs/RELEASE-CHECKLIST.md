# Native Release Checklist

## 1.1.1 scope

This release fixes packaging and operation-safety findings from the native audit. It does
not change the supported Homebrew command set or publish a website/release automatically.

## Automated gates

1. Update `Packaging/Info.plist`, `AppInfo.fallbackVersion`, `AppInfo.compiledBuild` and CHANGELOG.
2. Run `BREWWERY_LIVE=0 swift test --skip BrewweryLiveTests`.
   Run `swift Scripts/test-appcast.swift "$PWD/Scripts/verify-appcast.swift"` for offline
   appcast checks using synthetic data and a disposable signing key.
3. Run `bash Scripts/make-app.sh`. It asks SwiftPM for the output path using the same build
   arguments, then checks the packaged binary's version/build, both architectures, Mach-O
   UUIDs, licenses, translations, images, embedded Sparkle and code signature.
4. Repeat `bash Scripts/verify-app.sh dist/Brewwery.app` after copying/unzipping the bundle.
   Its `--build-info` probe does not start the GUI, Sparkle or Homebrew.

CI uses macos-26 / Xcode 26.6 from the
[runner image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).
Isolated tests also pass with Xcode 16.4, but its multi-architecture SwiftPM build fails
while generating the universal build graph. Use the newer toolchain for packaging;
the application's minimum macOS version remains 14.0.
It needs no signing secrets and never invokes the opt-in live tests. A successful workflow
is a build/test result, not a notarized public release.

## Manual release gates

- Launch the exact packaged app, confirm Settings/About version and build, credit link,
  licenses, English/German and both themes.
- Test from a fresh ZIP/DMG, move to Applications, quit/reopen and confirm local data survives.
  Use a uniquely named copy in Applications and `--qa-profile <new-name>` with
  `-ApplePersistenceIgnoreState YES` for isolated app data. Confirm empty Favorites/History,
  change a theme, add a favorite, run read-only Doctor, quit normally and reopen with the
  same profile. Check that all three persist, including a favorite added immediately before
  quitting. This does not sandbox Homebrew or validate Gatekeeper on a fresh macOS account.
- Test on Apple Silicon and real Intel hardware. Universal linking or Rosetta alone is not
  proof of Intel/macOS 14 compatibility.
- In an explicitly approved disposable Homebrew environment, test install/uninstall,
  upgrade, cancelled/failed partial operations, services, cleanup preview/run, tap/pin and
  metadata updates. Check History, counters and error recovery afterwards.
- Test keyboard navigation and VoiceOver manually. Rendering tests only cover snapshots.
- Produce the signed/notarized DMG only with explicit release approval. Verify Developer ID,
  stapling, Gatekeeper acceptance and Sparkle update from the previous installed release.
- Inspect the publicly uploaded DMG independently; a local good build cannot validate an
  older published binary. Publish the appcast only after these checks.
- Generate the feed in a release-specific directory containing only the new DMG. Do not
  advertise old archives under the new GitHub tag or delta files that were never uploaded.
  `swift Scripts/verify-appcast.swift <appcast> <dmg> <bundle/Contents/Info.plist>` checks
  version/build, minimum OS, URL, exact byte length and EdDSA signature with the public key.
- Compare SHA-256 after downloading the uploaded GitHub artifact, then promote the site's
  version, DMG and appcast together. Recheck the public URLs after deployment and record
  installed-app Sparkle QA separately from feed/signature verification.

## Remaining boundaries

- Favorites/History autosaves encode and write atomically on a serial background queue.
  Pending changes are coalesced and normal quit waits for completion. Initial JSON reads and
  explicit History export remain synchronous. Power loss/force-quit can lose an unwritten
  snapshot; atomic replacement preserves the previous valid file, not unsaved memory.
- Persistence tests prove off-main encoding and UI heartbeat continuity under an injected
  encoding delay; they are not real-device disk latency or throughput benchmarks.
- The mutation lock covers one Brewwery runner, not external Terminal commands or a second
  independently launched copy. Homebrew's own locks remain the last line of coordination.
- Configured local bundles may check Sparkle feeds; headless verification does not.
- A toolchain path fix does not certify the existing installed app or any published DMG.
