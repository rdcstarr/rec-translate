#!/usr/bin/env bash
#
# sign-notarize.sh — Developer ID sign (hardened runtime), notarize, staple, and build a DMG.
#
# Required env:
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
# Notarization (either the app-specific-password trio OR an App Store Connect API key):
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD
#   — or — AC_API_KEY_PATH, AC_API_KEY_ID, AC_API_ISSUER
set -euo pipefail

APP_NAME="RecTranslate"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/$APP_NAME.app"
ENTITLEMENTS="$ROOT/Resources/RecTranslate.entitlements"
DMG="$ROOT/build/$APP_NAME.dmg"

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your 'Developer ID Application: NAME (TEAMID)'}"
[ -d "$APP" ] || { echo "ERROR: $APP not found — run bundle.sh first"; exit 1; }

sign() { codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@"; }

echo "==> Signing nested code inside-out"
if [ -d "$APP/Contents/Frameworks" ]; then
  # Sparkle ships helper executables / XPC services / Updater.app that must each be signed.
  find "$APP/Contents/Frameworks" \
       \( -name "*.xpc" -o -name "Updater.app" -o -name "Autoupdate" \) -print0 |
    while IFS= read -r -d '' item; do
      echo "   signing $item"
      sign "$item"
    done
  find "$APP/Contents/Frameworks" -maxdepth 1 -name "*.framework" -type d -print0 |
    while IFS= read -r -d '' fw; do
      echo "   signing $fw"
      sign "$fw"
    done
fi

echo "==> Signing the app"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" "$APP"
# Note: no --deep here — Sparkle's docs warn against it (re-evaluates nested XPC signatures).
codesign --verify --strict --verbose=2 "$APP"

echo "==> Creating DMG"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "==> Notarizing"
if [ -n "${AC_API_KEY_PATH:-}" ]; then
  xcrun notarytool submit "$DMG" \
    --key "$AC_API_KEY_PATH" --key-id "$AC_API_KEY_ID" --issuer "$AC_API_ISSUER" --wait
else
  : "${APPLE_ID:?}"; : "${APPLE_TEAM_ID:?}"; : "${APPLE_APP_PASSWORD:?}"
  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
fi

echo "==> Stapling"
xcrun stapler staple "$APP"
xcrun stapler staple "$DMG"
echo "==> Done: $DMG"
