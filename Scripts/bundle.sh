#!/usr/bin/env bash
#
# bundle.sh — build the SwiftPM executable and assemble an (unsigned) RecTranslate.app.
# Usage: ./Scripts/bundle.sh [shortVersion] [buildNumber]
#
# Runs on macOS only (needs the macOS SDK + Xcode 26 toolchain).
set -euo pipefail

APP_NAME="RecTranslate"
CONFIG="release"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"

VERSION="${1:-0.1.0}"
BUILD_NUMBER="${2:-1}"

echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER) [universal, $CONFIG]"
swift build -c "$CONFIG" --arch arm64 --arch x86_64

BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"
[ -f "$EXECUTABLE" ] || { echo "ERROR: executable not found at $EXECUTABLE"; exit 1; }

echo "==> Assembling bundle at $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$EXECUTABLE" "$APP/Contents/MacOS/$APP_NAME"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Embed Sparkle.framework. Sparkle is an XCFramework binary target: for `swift build` it lives
# under .build/artifacts/.../Sparkle.xcframework/<slice>/Sparkle.framework (it is NOT copied into
# the bin dir), so scan artifacts first, then fall back to the bin dir / a broad .build scan.
SPARKLE_FW="$(find "$ROOT/.build/artifacts" -path '*Sparkle.xcframework*' -name 'Sparkle.framework' -type d 2>/dev/null | head -1)"
if [ -z "$SPARKLE_FW" ]; then
  SPARKLE_FW="$(find "$BIN_DIR" -maxdepth 1 -name 'Sparkle.framework' -type d 2>/dev/null | head -1)"
fi
if [ -z "$SPARKLE_FW" ]; then
  SPARKLE_FW="$(find "$ROOT/.build" -name 'Sparkle.framework' -type d 2>/dev/null | head -1)"
fi
if [ -n "$SPARKLE_FW" ]; then
  echo "==> Embedding Sparkle.framework from $SPARKLE_FW"
  cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/"
  # Let the executable find embedded frameworks at runtime.
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/$APP_NAME" 2>/dev/null || true
else
  echo "WARNING: Sparkle.framework not found — in-app updates will be unavailable in this bundle."
fi

echo "==> Built unsigned bundle: $APP"
