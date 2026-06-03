#!/usr/bin/env bash
# Bundle the `homebar` SwiftPM executable into a menu-bar-only HomeBar.app.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG" --product homebar
BIN="$(swift build -c "$CONFIG" --product homebar --show-bin-path)/homebar"

APP="build/HomeBar.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Sources/HomeBar/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/HomeBar"
# Copy any SwiftPM resource bundles sitting next to the binary (none today, but future-proof).
cp -R "$(dirname "$BIN")"/*.bundle "$APP/Contents/MacOS/" 2>/dev/null || true

# Embed Sparkle.framework (auto-updates) and make the bundle self-contained: SwiftPM links it
# via @rpath, so drop the absolute build-dir rpaths and point at Contents/Frameworks instead.
EXE="$APP/Contents/MacOS/HomeBar"
SPARKLE_FW="$(find .build/artifacts -type d -path '*Sparkle.xcframework/macos-*/Sparkle.framework' | head -1)"
if [ -n "$SPARKLE_FW" ]; then
  mkdir -p "$APP/Contents/Frameworks"
  ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
  for rp in $(otool -l "$EXE" | grep -A2 LC_RPATH | grep 'path ' | awk '{print $2}' | grep '\.build'); do
    install_name_tool -delete_rpath "$rp" "$EXE" 2>/dev/null || true
  done
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXE" 2>/dev/null || true
  echo "Embedded $(basename "$(dirname "$(dirname "$SPARKLE_FW")")") Sparkle.framework"
else
  echo "WARNING: Sparkle.framework not found — build first so SwiftPM fetches it." >&2
fi

# Ad-hoc sign inner-to-outer (--deep is fine without entitlements; switch to per-component
# Developer ID signing when adding notarization).
echo "Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "Built $APP"
echo "Run with:  open $APP"
