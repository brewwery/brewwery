# Contributing

Please keep changes scoped, readable, and macOS-first.

## Local development

Requires macOS 14 or later and Xcode 16 or later.

```bash
swift build
swift run Brewwery
swift test
```

Open `Package.swift` in Xcode to work in the IDE. `Scripts/make-app.sh` builds a runnable
`Brewwery.app` in `dist/`.

`swift test` never touches your Homebrew installation. Tests that do are opt-in — see
[README › Tests](README.md#tests) before running `BrewweryLiveTests`.

## Guidelines

- Homebrew is only ever run through `HomebrewCommand`: no shell, no free-form arguments, and
  every dynamic value validated in `HomebrewIdentifier`.
- Anything that changes Homebrew needs an explicit confirmation in the UI.
- Do not add telemetry, authentication, cloud sync, or monetization.
- Icon-only buttons are `IconButton`, so they always carry an accessible name.
- Add or update tests with the change, and record departures from existing behaviour in
  `docs/ARCHITECTURE-DECISIONS.md`.
