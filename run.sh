#!/bin/bash
# Build, codesign with CloudKit entitlements, install to /Applications, and launch Loom.
# Signs with Apple Development certificate and embedded provisioning profile
# so macOS Accessibility permissions persist and CloudKit works.

set -e

APP="/Applications/Loom.app"
BINARY="$APP/Contents/MacOS/Loom"
CERT="Apple Development: Barel Oved (S9JRY7P6M6)"
ENTITLEMENTS="Loom/Loom.entitlements"
PROFILE="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/5090bf3a-4570-475c-a812-f5a5ab1381d1.provisionprofile"

echo "Building release..."
swift build -c release

echo "Installing to $APP..."
cp .build/release/Loom "$BINARY"
cp -R .build/release/Loom_Loom.bundle "$APP/Contents/Resources/Loom_Loom.bundle"

echo "Embedding provisioning profile..."
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

echo "Updating bundle identifier..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.bareloved.LoomMac" "$APP/Contents/Info.plist"

echo "Codesigning with entitlements..."
codesign --force --sign "$CERT" --entitlements "$ENTITLEMENTS" "$APP"

echo "Launching Loom..."
open "$APP"
