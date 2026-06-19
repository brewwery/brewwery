# Known Issues

Known issues and release-candidate decisions for Brewwery v0.9.3.

## External Release Constraints

| Item | Status | Decision |
| --- | --- | --- |
| Unsigned / not notarized builds | Open | Apple Developer signing assets are not available yet. Continue producing clearly documented unsigned Release Candidate builds; prepare signed/notarized v1.0 artifacts when the account is ready. |
| Local DMG APFS failure | Open locally | `hdiutil create ... -fs APFS` fails on this development Mac. Keep local `.app` and ZIP verification; produce the DMG on a clean GitHub Actions macOS runner. |
| Intel / universal runtime validation | Untested | Build scripts exist, but Apple Silicon remains the supported v1.0 target. Do not claim Intel support until the x64 native addon and packaged app are tested on Intel hardware. |

## Engineering Follow-ups

| Item | Priority | Plan |
| --- | --- | --- |
| Cleanup and service actions do not stream live output | Non-blocking | Services are normally short; cleanup shows preview and final results. Move unified streaming to a post-v1.0 release unless QA finds UI blocking. |
| Long-running operations cannot be cancelled from the UI | Medium | Add an allowlisted cancel IPC tied to active operation IDs; never expose arbitrary process control. |
| Command timeouts are not enforced | Medium | Add operation-specific timeouts and a friendly timeout error without interrupting normal long Homebrew installs. |
| Automatic app updates are not implemented | Post-v1.0 | Add only after signing/notarization and release feed decisions are complete. |
| Accessibility full pass is pending | Pre-v1.0 QA | Verify keyboard navigation, focus visibility, VoiceOver labels, and light/dark contrast. |

## Closed in v0.9.3

- Large install/uninstall/upgrade output is bounded in Electron main and renderer memory.
- Formulae, casks, updates, services, cleanup, and doctor parser behavior has Rust regression coverage.
- Formula, cask, search, upgrade, and service identifier validation has regression coverage.
- Common read/diagnostics error states provide a direct Retry action.

## Existing Intentional Constraints

- Discovery search accepts only ASCII Homebrew package-name characters.
- Custom Homebrew path validation requires an absolute executable path that can run `brew --version`.
- History stores trimmed output for very large operation logs to keep the app responsive.
- Open Terminal and package-path placeholders remain hidden until implemented safely.
- No telemetry or crash reporting is included by design.
- No cloud sync, accounts, paid/pro features, or donations are included.
- Linux, Windows, and package managers beyond Homebrew are out of scope.
