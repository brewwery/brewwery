# Security

Please report security issues privately to [pint@brewwery.com](mailto:pint@brewwery.com)
before opening a public issue. Include the app version, affected operation and a minimal
reproduction. Remove tokens, private paths and personal data from attachments. Sending a
report does not upload diagnostics automatically.

Brewwery sits between you and a package manager, so its rules are conservative: no shell, no
arbitrary commands, no telemetry, and every change to Homebrew is allowlisted and confirmed.
The security model is described in the [README](README.md#security) and the reasoning behind
it in [docs/ARCHITECTURE-DECISIONS.md](docs/ARCHITECTURE-DECISIONS.md).

Metadata changes, taps, pin/unpin and streamed mutations share one reservation, acquired
before asynchronous detection. Read-only commands may run concurrently; cancelling their
task terminates their own child group. Custom brew executables are trusted user input, not
sandboxed programs: validation checks the path and version response, not binary provenance.

The desktop app sends no analytics or account data. Homebrew accesses its metadata/package
hosts; Sparkle accesses the configured appcast and update assets. The website's analytics
are separate. Local ad-hoc builds are not notarized; a public release requires the signing,
notarization and installed-app checks in [RELEASE-CHECKLIST](docs/RELEASE-CHECKLIST.md).
