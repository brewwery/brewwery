# Known Issues

Known issues for the current private beta.

## v0.7.2-beta.3

- Builds are unsigned and not notarized. macOS Gatekeeper may warn before launch.
- Apple Silicon is the primary tested architecture.
- Intel and universal builds are configured but may be untested.
- Local DMG creation currently fails on this machine at `hdiutil create ... -fs APFS`. Use `pnpm package:mac:dir` or `pnpm package:mac:zip` for local verification and GitHub Actions for release DMG artifacts.
- Long-running Homebrew operations depend on Homebrew stdout/stderr output. Some commands may appear quiet until Homebrew emits output.
- Cleanup and service actions currently show final operation output rather than live streaming progress.
- Tapped formula names containing `/` are rejected by the strict v0.4 package-name validator.
- Discovery search accepts only ASCII Homebrew package-name characters.
- Package path and Open Terminal shortcuts from package detail are placeholders.
- Custom Homebrew path validation requires an absolute executable path that can run `brew --version`.
- No telemetry or crash reporting is included by design.
- No cloud sync is included.
- No paid/pro features are included.
- Builds are not auto-updated yet.
- History stores trimmed output for very large operation logs to keep the app responsive.
