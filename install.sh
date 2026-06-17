#!/bin/bash
#
# RecTranslate one-command installer (free / ad-hoc build).
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rdcstarr/rec-translate/main/install.sh)"
#
# Downloads the latest release build, installs it to Applications, clears the Gatekeeper
# quarantine (these builds are ad-hoc signed, not notarized), and launches it.
set -euo pipefail

REPO="rdcstarr/rec-translate"
APP="RecTranslate.app"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/RecTranslate.zip"

command -v curl >/dev/null || { echo "ERROR: curl is required."; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading RecTranslate…"
curl -fSL "$ZIP_URL" -o "$TMP/RecTranslate.zip" || {
  echo "ERROR: could not download $ZIP_URL"
  echo "       (Has a release been published yet?)"
  exit 1
}

echo "==> Unpacking…"
ditto -x -k "$TMP/RecTranslate.zip" "$TMP/extracted"
SRC="$(/usr/bin/find "$TMP/extracted" -maxdepth 2 -name "$APP" -type d | head -1)"
[ -n "$SRC" ] || { echo "ERROR: $APP not found inside the archive."; exit 1; }

DEST="/Applications"
if [ ! -w "$DEST" ]; then
  DEST="$HOME/Applications"
  mkdir -p "$DEST"
fi

echo "==> Installing to $DEST…"
rm -rf "${DEST:?}/$APP"
ditto "$SRC" "$DEST/$APP"

echo "==> Clearing Gatekeeper quarantine…"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

echo "==> Launching…"
open "$DEST/$APP"

cat <<EOF

✅ RecTranslate is installed in $DEST and running — look for the speech-bubble icon in the menu bar.

Next steps:
  1. Click the menu-bar icon → Settings…
  2. Paste your rec-app translate API key (the one with the "translate" ability).
     The base URL defaults to https://rec-app.recweb.app — change it there if needed.
  3. Press your hotkey (⌥Space, or double-tap Shift) and start translating.
EOF
