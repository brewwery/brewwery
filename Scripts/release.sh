#!/bin/bash
#
# Produces a notarised, stapled Brewwery DMG and the Sparkle appcast entry for it.
#
#   1. builds and signs Brewwery.app                       (Scripts/make-app.sh)
#   2. notarises and staples the app
#   3. wraps it in a signed DMG with an Applications link
#   4. notarises and staples the DMG
#   5. signs the DMG for Sparkle and regenerates appcast.xml
#
# Credentials never appear here: signing uses the Developer ID certificate in the keychain,
# notarisation a stored `notarytool` keychain profile, and the Sparkle signature the EdDSA key
# stored under the keychain account "brewwery".
#
# Usage:
#   Scripts/release.sh --sign "Developer ID Application: …" \
#       [--notary-profile NAME (default: Brewwery)] [--download-url-prefix URL] [--channel beta]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDENTITY=""
PROFILE="${NOTARY_PROFILE:-Brewwery}"
CHANNEL=""
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Packaging/Info.plist")
DOWNLOAD_PREFIX="https://github.com/brewwery/brewwery/releases/download/v$VERSION/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign) IDENTITY="$2"; shift 2 ;;
    --notary-profile) PROFILE="$2"; shift 2 ;;
    --download-url-prefix) DOWNLOAD_PREFIX="$2"; shift 2 ;;
    --channel) CHANNEL="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$IDENTITY" ]] || { echo "error: --sign \"Developer ID Application: …\" is required" >&2; exit 1; }
[[ -n "$PROFILE" ]] || { echo "error: --notary-profile (or NOTARY_PROFILE) is required" >&2; exit 1; }
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1 || {
  echo "error: no notarytool keychain profile named \"$PROFILE\"." >&2
  echo "       create one with: xcrun notarytool store-credentials \"$PROFILE\"" >&2
  exit 1
}

DIST="$ROOT/dist"
RELEASE="$DIST/release-$VERSION"
APPCAST_DIR="$DIST/appcast"
APP="$RELEASE/Brewwery.app"
DMG="$APPCAST_DIR/Brewwery-$VERSION.dmg"
SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"

rm -rf "$RELEASE"
mkdir -p "$RELEASE" "$APPCAST_DIR"

"$ROOT/Scripts/make-app.sh" --sign "$IDENTITY" --output "$RELEASE"

echo "==> Notarising the app"
ditto -c -k --keepParent "$APP" "$RELEASE/Brewwery-notarize.zip"
xcrun notarytool submit "$RELEASE/Brewwery-notarize.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm "$RELEASE/Brewwery-notarize.zip"

echo "==> Building the DMG"
STAGING="$RELEASE/dmg"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Brewwery.app"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Brewwery $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarising the DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "==> Updating the Sparkle appcast"
# macOS ships bash 3.2, where expanding an empty array under `set -u` is an error.
CHANNEL_ARGS=()
[[ -n "$CHANNEL" ]] && CHANNEL_ARGS=(--channel "$CHANNEL")
"$SPARKLE_BIN/generate_appcast" --account brewwery \
  --download-url-prefix "$DOWNLOAD_PREFIX" \
  ${CHANNEL_ARGS[@]+"${CHANNEL_ARGS[@]}"} \
  "$APPCAST_DIR"

shasum -a 256 "$DMG"
echo "==> Done"
echo "    DMG:     $DMG"
echo "    Appcast: $APPCAST_DIR/appcast.xml  (publish at the SUFeedURL in Packaging/Info.plist)"
echo "    Upload the DMG so it is reachable at: $DOWNLOAD_PREFIX$(basename "$DMG")"
