#!/bin/bash
# Build, codesign, install to /Applications, and launch Loom.
# Signs with Apple Development certificate so macOS Accessibility
# permissions persist across rebuilds.

set -e

APP="/Applications/Loom.app"
BINARY="$APP/Contents/MacOS/Loom"
CERT="Apple Development: bareloved@gmail.com (K2V49Q795A)"

echo "Building release..."
swift build -c release

echo "Installing to $APP..."
cp .build/release/Loom "$BINARY"
cp -R .build/release/Loom_Loom.bundle "$APP/Contents/Resources/Loom_Loom.bundle"

echo "Codesigning with: $CERT"
codesign --force --sign "$CERT" "$APP"

echo "Launching Loom..."
open "$APP"
