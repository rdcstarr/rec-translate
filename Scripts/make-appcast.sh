#!/usr/bin/env bash
#
# make-appcast.sh — produce a Sparkle appcast.xml that points at the released DMG, signing the
# update with the EdDSA private key.
#
# Required env:
#   SPARKLE_BIN              directory containing Sparkle's `generate_appcast` tool
#   SPARKLE_PRIVATE_KEY_FILE path to a file holding the EdDSA private key (from `generate_keys`)
#   DOWNLOAD_URL_PREFIX      public URL prefix where the DMG will be downloadable
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
UPDATES_DIR="$BUILD_DIR/updates"

: "${SPARKLE_BIN:?Set SPARKLE_BIN to Sparkle's bin directory (contains generate_appcast)}"
: "${SPARKLE_PRIVATE_KEY_FILE:?Set SPARKLE_PRIVATE_KEY_FILE to the EdDSA private key file}"
: "${DOWNLOAD_URL_PREFIX:?Set DOWNLOAD_URL_PREFIX to the public release download URL prefix}"

mkdir -p "$UPDATES_DIR"
# generate_appcast scans the folder of archives (the DMG copied here by CI).
"$SPARKLE_BIN/generate_appcast" \
  --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  -o "$BUILD_DIR/appcast.xml" \
  "$UPDATES_DIR"

echo "==> appcast.xml written to $BUILD_DIR/appcast.xml"
