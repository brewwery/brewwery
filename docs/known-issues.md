# Known Issues

Known issues and release-candidate decisions for Brewwery v0.9.2.

## Release Candidate Decisions

| Item | Decision | Notes |
| --- | --- | --- |
| Unsigned / not notarized builds | Keep for v0.9.2 | Builds are unsigned during Release Candidate testing. Signing and notarization are prepared for v1.0 if Apple Developer assets are ready. |
| Local DMG APFS issue | Keep documented | Confirmed during v0.9 RC testing: local `hdiutil create ... -fs APFS` fails on this machine. Use `pnpm package:mac:dir` or `pnpm package:mac:zip` locally, and use GitHub Actions on a clean macOS runner for release DMG artifacts. |
| Intel / universal build validation | Move to v1.1 if needed | Build scripts exist, but Apple Silicon remains the recommended v1.0 target. Intel and universal builds need dedicated runtime validation. |
| Cleanup/service actions without streaming progress | Move to v1.1 | Install, uninstall, and upgrade have streaming progress. Cleanup and service actions currently show final result output only. |
| Open Terminal / package path placeholders | Fixed for v0.8 | Placeholder actions are hidden from the primary UI until they can be implemented safely. No fake clickable actions should remain. |
| Tapped formula names containing `/` | Fixed for v0.9.2 | Formula identifiers now allow slash-separated tap names while cask tokens remain strict. |

## Current Known Limitations

- Apple Silicon is the primary tested architecture.
- Builds are unsigned and not notarized.
- Local DMG creation currently fails on this machine because of the APFS `hdiutil` issue.
- `pnpm package:mac:x64` and `pnpm package:mac:universal` currently require the Rust `x86_64-apple-darwin` target; this machine does not have that target installed.
- Cleanup and service actions do not yet use the live streaming progress panel.
- Discovery search accepts only ASCII Homebrew package-name characters.
- Custom Homebrew path validation requires an absolute executable path that can run `brew --version`.
- History stores trimmed output for very large operation logs to keep the app responsive.
- No telemetry or crash reporting is included by design.
- No cloud sync is included.
- No paid/pro features are included.
- No donations/support links are included.
- Automatic app updates are not implemented yet.

## Not Considered Issues

- No Linux support: intentionally out of scope.
- No Windows support: intentionally out of scope.
- No package managers beyond Homebrew: intentionally out of scope.
