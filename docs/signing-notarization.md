# Signing And Notarization

Brewwery v0.9.0 prepares signing configuration, but Release Candidate builds remain unsigned unless Apple Developer assets are available.

## Decision

- v0.9.0: unsigned Release Candidate builds are acceptable for private QA.
- v1.0: target a signed and notarized Apple Silicon build if Apple Developer Program access is ready.
- Fallback: if signing is not ready, keep the build private/limited and document Gatekeeper warnings clearly.

## Required Apple Assets

- Apple Developer Program membership.
- Developer ID Application certificate.
- Apple notarization credentials:
  - App Store Connect API key, issuer id, and key id, or
  - Apple ID plus app-specific password.

## GitHub Actions Secrets

Recommended secrets for a signed/notarized pipeline:

```text
CSC_LINK
CSC_KEY_PASSWORD
APPLE_API_KEY
APPLE_API_KEY_ID
APPLE_API_ISSUER
APPLE_TEAM_ID
```

Alternative Apple ID notarization secrets:

```text
APPLE_ID
APPLE_APP_SPECIFIC_PASSWORD
APPLE_TEAM_ID
```

## Current electron-builder Preparation

Brewwery includes macOS entitlements for future hardened runtime builds:

- `desktop/entitlements.mac.plist`
- `desktop/entitlements.mac.inherit.plist`

The current config sets:

- bundle id: `com.brewwery.app`
- hardened runtime: enabled
- macOS category: `public.app-category.utilities`
- app icon: `desktop/assets/brewwery-icon.png`

Without signing secrets/certificates, `electron-builder` skips signing and produces unsigned local artifacts.

## Manual Unsigned Install Note

Unsigned builds may show a macOS Gatekeeper warning. For private QA, testers may need to right-click the app, choose Open, and confirm. This is expected until Developer ID signing and notarization are configured.

Do not ask testers to disable Gatekeeper globally.
