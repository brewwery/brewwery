#!/bin/bash
#
# Builds Brewwery.app from the SwiftPM package.
#
# The bundle is universal (Apple Silicon and Intel), embeds Sparkle.framework, and — with
# --sign — is signed inside-out with the hardened runtime, as notarisation requires. It is not
# sandboxed: Brewwery runs the user's own `brew`.
#
# Usage:
#   Scripts/make-app.sh [--sign "Developer ID Application: …"] [--output dir]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDENTITY=""
OUTPUT="$ROOT/dist"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign) IDENTITY="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

PRODUCTS="$ROOT/.build/apple/Products/Release"
APP="$OUTPUT/Brewwery.app"
CONTENTS="$APP/Contents"

echo "==> Building universal release (arm64, x86_64)"
swift build --package-path "$ROOT" --configuration release --arch arm64 --arch x86_64

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"

cp "$PRODUCTS/Brewwery" "$CONTENTS/MacOS/Brewwery"
cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
printf 'APPL????' > "$CONTENTS/PkgInfo"
ditto "$PRODUCTS/Sparkle.framework" "$CONTENTS/Frameworks/Sparkle.framework"

# Images go straight into Contents/Resources. SwiftPM's resource bundle is deliberately not
# shipped: its generated accessor only looks beside the .app or at this machine's build path.
for image in AppIcon MenuBarIcon WordmarkDark WordmarkLight; do
  cp "$ROOT/Sources/Brewwery/Resources/$image.png" "$CONTENTS/Resources/$image.png"
done

echo "==> Building the icon set"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 64 128 256 512; do
  sips -z $size $size "$ROOT/Sources/Brewwery/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$ROOT/Sources/Brewwery/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

if [[ -z "$IDENTITY" ]]; then
  # An ad-hoc signature keeps a local build launchable; it cannot be notarised.
  codesign --force --sign - --deep "$APP" >/dev/null
  echo "==> Unsigned (ad-hoc) build: $APP"
  exit 0
fi

echo "==> Signing inside-out with the hardened runtime"
SPARKLE="$CONTENTS/Frameworks/Sparkle.framework/Versions/B"
sign() { codesign --force --timestamp --options runtime --sign "$IDENTITY" "$@"; }

sign "$SPARKLE/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
sign "$SPARKLE/Autoupdate"
sign "$SPARKLE/Updater.app"
sign "$CONTENTS/Frameworks/Sparkle.framework"
sign --entitlements "$ROOT/Packaging/Brewwery.entitlements" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
echo "==> Signed: $APP"
