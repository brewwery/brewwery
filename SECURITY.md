# Security

Please report security issues privately to the maintainers before opening a public issue.

Brewwery sits between you and a package manager, so its rules are conservative: no shell, no
arbitrary commands, no telemetry, and every change to Homebrew is allowlisted and confirmed.
The security model is described in the [README](README.md#security) and the reasoning behind
it in [docs/ARCHITECTURE-DECISIONS.md](docs/ARCHITECTURE-DECISIONS.md).
