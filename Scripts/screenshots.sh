#!/bin/bash
#
# Captures the marketing and documentation screenshots from the real app window.
#
# The app runs as a debug build in demo mode (see Sources/Brewwery/App/DemoLaunch.swift)
# against Scripts/demo-brew.sh, so the images are reproducible and show no real machine's
# packages, paths or history. Each capture is the window with its system shadow on a
# transparent background, scaled to 1800 px wide.
#
# Usage: Scripts/screenshots.sh [output-directory]
#
# The terminal running this needs the Screen Recording permission.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$ROOT/dist/screenshots}"
WORK="$(mktemp -d)"
trap 'pkill -f "Brewwery Screenshots.app" 2>/dev/null || true; rm -rf "$WORK"' EXIT

mkdir -p "$OUTPUT"
cp "$ROOT/Scripts/demo-brew.sh" "$WORK/brew"
chmod +x "$WORK/brew"

echo "==> Building debug app"
swift build --package-path "$ROOT" >/dev/null

# Wrap the debug binary in a throwaway bundle so it can be launched with `open`: macOS only
# gives a newly launched app the key window — coloured traffic lights, active controls — when
# LaunchServices starts it. A distinct bundle identifier keeps Sparkle from starting.
APP="$WORK/Brewwery Screenshots.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp "$ROOT/.build/debug/Brewwery" "$APP/Contents/MacOS/Brewwery"
ditto "$ROOT/.build/debug/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.brewwery.app.screenshots" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1

# Finds the on-screen window of the process just launched.
cat > "$WORK/window-id.swift" <<'SWIFT'
import CoreGraphics
import Foundation
let pid = Int32(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows where (window[kCGWindowOwnerPID as String] as? Int32) == pid {
    if let bounds = window[kCGWindowBounds as String] as? [String: Any], (bounds["Height"] as? Double ?? 0) > 400 {
        print(window[kCGWindowNumber as String]!)
        exit(0)
    }
}
exit(1)
SWIFT
swiftc -O "$WORK/window-id.swift" -o "$WORK/window-id" 2>/dev/null

capture() {
  local page="$1" theme="$2" name="$3" search="${4:-}"
  # SHOTS_ONLY="Packages Search-Light" recaptures just those images.
  if [[ -n "${SHOTS_ONLY:-}" && " $SHOTS_ONLY " != *" $name "* ]]; then return 0; fi
  local args=(-BrewweryDemoHomebrew "$WORK/brew" -BrewweryDemoPage "$page" -BrewweryDemoTheme "$theme")
  [[ -n "$search" ]] && args+=(-BrewweryDemoSearch "$search")

  open -n "$APP" --args "${args[@]}"
  local pid="" id=""
  for _ in $(seq 1 50); do
    pid=$(pgrep -nf "Brewwery Screenshots.app/Contents/MacOS/Brewwery" || true)
    [[ -n "$pid" ]] && break
    sleep 0.2
  done
  [[ -n "$pid" ]] || { echo "error: app did not launch for $name" >&2; exit 1; }
  for _ in $(seq 1 50); do
    id=$("$WORK/window-id" "$pid" 2>/dev/null || true)
    [[ -n "$id" ]] && break
    sleep 0.2
  done
  [[ -n "$id" ]] || { echo "error: no window for $name" >&2; kill "$pid"; exit 1; }

  sleep 4  # let data load and the debounced search settle

  # Bring the window to the front immediately before capturing so it has the key-window look
  # (coloured traffic lights, active controls). Focus can drift back to whatever app was in use
  # while the data loads, and becoming key lags behind activation, so take a few captures and
  # keep the tallest: an active window casts a larger shadow than an inactive one.
  local best=0
  for attempt in 1 2 3; do
    osascript -e 'tell application id "com.brewwery.app.screenshots" to activate' >/dev/null 2>&1 || true
    sleep 1.5
    screencapture -x -l "$id" "$WORK/attempt.png"
    local height
    height=$(sips -g pixelHeight "$WORK/attempt.png" | awk '/pixelHeight/ { print $2 }')
    if (( height > best )); then
      best=$height
      mv "$WORK/attempt.png" "$OUTPUT/$name.png"
    fi
  done
  sips --resampleWidth 1800 "$OUTPUT/$name.png" >/dev/null
  kill "$pid" 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
  echo "    $name.png"
}

echo "==> Capturing"
for theme in dark light; do
  suffix=""; [[ "$theme" == "light" ]] && suffix="-Light"
  capture dashboard "$theme" "Dashboard$suffix"
  capture search "$theme" "Search$suffix" postgres
  capture updates "$theme" "Updates$suffix"
  capture settings "$theme" "Settings$suffix"
  capture packages "$theme" "Packages$suffix"
  capture services "$theme" "Services$suffix"
done
echo "==> Done: $OUTPUT"
