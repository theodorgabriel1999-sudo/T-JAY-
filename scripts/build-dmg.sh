#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash scripts/build-app.sh
APP="build/JARVIS AI Workstation.app"
if [[ "${1:-}" == "--sign" || "${1:-}" == "--notarize" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity}"
  codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi
mkdir -p dist
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="dist/JARVIS-AI-Workstation-1.0.0.dmg"
rm -f "$DMG"
hdiutil create -volname "JARVIS AI Workstation" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [[ "${1:-}" == "--notarize" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "JARVIS_NOTARY" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
echo "Created $DMG"
