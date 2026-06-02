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

echo "Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "Built $APP"
echo "Run with:  open $APP"
