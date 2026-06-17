#!/bin/bash
#
# RecTranslate one-command installer (free / ad-hoc build).
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/rdcstarr/rec-translate/main/install.sh)"
#
# Downloads the latest release build, installs it to Applications, clears the Gatekeeper
# quarantine (these builds are ad-hoc signed, not notarized), and launches it.
#
# NOTE: ASCII-only, fully braced ${VAR} expansions -- so it is safe in any locale (a multibyte
# char glued to a bare $VAR can otherwise be misparsed as part of the variable name).
set -euo pipefail

REPO="rdcstarr/rec-translate"
APP="RecTranslate.app"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/RecTranslate.zip"

command -v curl >/dev/null || { echo "ERROR: curl is required."; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "==> Downloading RecTranslate..."
curl -fSL "${ZIP_URL}" -o "${TMP}/RecTranslate.zip" || {
  echo "ERROR: could not download ${ZIP_URL}"
  echo "       (Has a release been published yet?)"
  exit 1
}

echo "==> Unpacking..."
ditto -x -k "${TMP}/RecTranslate.zip" "${TMP}/extracted"
SRC="$(/usr/bin/find "${TMP}/extracted" -maxdepth 2 -name "${APP}" -type d | head -1)"
[ -n "${SRC}" ] || { echo "ERROR: ${APP} not found inside the archive."; exit 1; }

DEST="/Applications"
if [ ! -w "${DEST}" ]; then
  DEST="${HOME}/Applications"
  mkdir -p "${DEST}"
fi

# Quit any running instance so the `open` below launches the NEW version — `open` only activates
# an already-running app, it does not relaunch it.
echo "==> Closing any running instance..."
osascript -e 'quit app "Rec Translate"' >/dev/null 2>&1 || true
killall RecTranslate >/dev/null 2>&1 || true
sleep 1

echo "==> Installing to ${DEST} ..."
rm -rf "${DEST:?}/${APP}"
ditto "${SRC}" "${DEST}/${APP}"

echo "==> Clearing Gatekeeper quarantine..."
xattr -dr com.apple.quarantine "${DEST}/${APP}" 2>/dev/null || true

# Register with LaunchServices so Finder/Launchpad show the icon and the first launch is reliable
# (a freshly-copied bundle is otherwise not registered yet, so the first `open` can no-op).
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
[ -x "${LSREGISTER}" ] && "${LSREGISTER}" -f "${DEST}/${APP}" >/dev/null 2>&1 || true

echo "==> Launching..."
open "${DEST}/${APP}" || { sleep 1; open "${DEST}/${APP}"; }

echo ""
echo "Done. Rec Translate is installed in ${DEST} and running -- look for the speech-bubble icon in the menu bar."
echo ""
echo "Next steps:"
echo "  1. Click the menu-bar icon, then Settings..."
echo "  2. Paste your rec-app translate API key (the one with the 'translate' ability)."
echo "     The base URL defaults to https://rec-app.recweb.app"
echo "  3. Press your hotkey (Option+Space, or double-tap Shift) and translate."
