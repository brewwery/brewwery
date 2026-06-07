# Known Issues

Known issues for the current Launch Candidate.

## v0.8.0

- Keep: builds are unsigned and not notarized. macOS Gatekeeper may warn before launch.
- Keep: Apple Silicon is the primary tested architecture.
- Move to v0.9: Intel and universal builds are configured but still need dedicated validation.
- Move to v0.9: local DMG creation can fail on this machine at `hdiutil create ... -fs APFS`; use `pnpm package:mac:dir` or `pnpm package:mac:zip` locally and GitHub Actions for release DMG artifacts.
- Move to v0.9: cleanup and service actions currently show final operation output rather than live streaming progress.
- Move to v0.9: tapped formula names containing `/` are rejected by the strict package-name validator.
- Keep: discovery search accepts only ASCII Homebrew package-name characters.
- Fixed for v0.8: package path and package-detail Terminal placeholders are hidden from the detail drawer.
- Keep: custom Homebrew path validation requires an absolute executable path that can run `brew --version`.
- Keep: no telemetry or crash reporting is included by design.
- Keep: no cloud sync is included.
- Keep: no paid/pro features are included.
- Move to v0.9: builds are not auto-updated yet.
- Keep: History stores trimmed output for very large operation logs to keep the app responsive.
