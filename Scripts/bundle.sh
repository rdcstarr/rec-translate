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

# Rasterize the flag SVGs into PNG resources before building (macOS has no runtime SVG decoder).
if [ -x "$ROOT/Scripts/rasterize-flags.sh" ]; then
  "$ROOT/Scripts/rasterize-flags.sh" || echo "WARNING: flag rasterization failed; flags fall back to emoji"
fi

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

# App icon: compile AppIcon.icns from the iconset with Apple's iconutil (macOS), or copy a prebuilt one.
if [ -d "$ROOT/Resources/AppIcon.iconset" ]; then
  iconutil -c icns "$ROOT/Resources/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
  echo "==> Built AppIcon.icns from iconset"
elif [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# Copy SwiftPM resource bundles (e.g. KeyboardShortcuts localizations) into Resources so that
# `Bundle.module` resolves at runtime. Without this, opening Settings crashes when the shortcut
# Recorder loads (Bundle.module fatalErrors). Auto-update needs no embedded framework anymore.
copied_bundle=0
while IFS= read -r b; do
  [ -n "$b" ] || continue
  cp -R "$b" "$APP/Contents/Resources/"
  echo "==> Embedded resource bundle: $(basename "$b")"
  copied_bundle=1
done < <(find "$BIN_DIR" -maxdepth 1 -name '*.bundle' -type d 2>/dev/null)
if [ "$copied_bundle" -eq 0 ]; then
  KS_BUNDLE="$(find "$ROOT/.build" -name 'KeyboardShortcuts_*.bundle' -type d 2>/dev/null | head -1)"
  if [ -n "$KS_BUNDLE" ]; then
    cp -R "$KS_BUNDLE" "$APP/Contents/Resources/"
    echo "==> Embedded resource bundle (fallback): $(basename "$KS_BUNDLE")"
  else
    echo "WARNING: no SwiftPM resource bundle found — Settings may crash on the shortcut recorder."
  fi
fi

echo "==> Built unsigned bundle: $APP"
