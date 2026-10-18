#!/bin/bash
# Verifies the packaged executable without opening a window or invoking Homebrew.
set -euo pipefail
APP="${1:?Usage: verify-app.sh path/to/Brewwery.app [built executable]}"
BINARY="$APP/Contents/MacOS/Brewwery"
PLIST="$APP/Contents/Info.plist"
INFO="$("$BINARY" --build-info)"
for mapping in 'version CFBundleShortVersionString' 'build CFBundleVersion' 'bundleIdentifier CFBundleIdentifier'; do
  read -r field key <<< "$mapping"
  actual="$(printf '%s' "$INFO" | plutil -extract "$field" raw -o - -)"
  expected="$(plutil -extract "$key" raw -o - "$PLIST")"
  [[ "$actual" == "$expected" ]] || { echo "Executable/plist mismatch: $field" >&2; exit 1; }
done
[[ "$(printf '%s' "$INFO" | plutil -extract channel raw -o - -)" == Stable ]]
for arch in arm64 x86_64; do
  lipo "$BINARY" -verify_arch "$arch"
  lipo "$APP/Contents/Frameworks/Sparkle.framework/Sparkle" -verify_arch "$arch"
  minimum="$(xcrun vtool -arch "$arch" -show-build "$BINARY" | awk '$1 == "minos" { print $2 }')"
  [[ "$minimum" == "$(plutil -extract LSMinimumSystemVersion raw -o - "$PLIST")" ]]
done
if [[ $# -gt 1 ]]; then
  # Mach-O UUIDs survive signing and identify the linked binary for both architectures.
  diff <(dwarfdump --uuid "$2" | awk '{print $2, $3}') \
       <(dwarfdump --uuid "$BINARY" | awk '{print $2, $3}')
fi
for resource in AppIcon.icns MenuBarIcon.png WordmarkDark.png WordmarkLight.png LICENSE.txt Sparkle-LICENSE.txt; do
  test -s "$APP/Contents/Resources/$resource"
done
for language in en de; do
  # Source-language literals need only a stringsdict when the catalog has plurals.
  test -s "$APP/Contents/Resources/$language.lproj/Localizable.strings" ||
    test -s "$APP/Contents/Resources/$language.lproj/Localizable.stringsdict"
done
test -d "$APP/Contents/Frameworks/Sparkle.framework"
codesign --verify --deep --strict "$APP"
echo "==> Verified packaged executable: $INFO"
