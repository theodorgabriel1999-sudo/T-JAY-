#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
step() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"; }
step "JARVIS 1.0.1 DMG build started"
bash scripts/build-app.sh
APP="build/JARVIS AI Workstation.app"
if [[ ! -d "$APP" || ! -x "$APP/Contents/MacOS/JARVISAIWorkstation" ]]; then
  echo "ERROR: app bundle is incomplete; refusing to package." >&2
  exit 1
fi
if [[ "${1:-}" == "--sign" || "${1:-}" == "--notarize" ]]; then
  step "Signing application with Developer ID"
  : "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity}"
  codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi
step "Preparing DMG staging folder"
mkdir -p dist
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="dist/JARVIS-AI-Workstation-1.0.1.dmg"
rm -f "$DMG"
step "Creating compressed disk image"
hdiutil create -volname "JARVIS AI Workstation" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [[ "${1:-}" == "--notarize" ]]; then
  step "Submitting disk image for notarization"
  xcrun notarytool submit "$DMG" --keychain-profile "JARVIS_NOTARY" --wait
  step "Stapling and validating notarization ticket"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
hdiutil verify "$DMG"
step "SUCCESS: Created and verified $DMG"
