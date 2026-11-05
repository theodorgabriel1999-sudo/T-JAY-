#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
./scripts/build-app.sh
mkdir -p dist
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "build/JARVIS AI Workstation.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
DMG="dist/JARVIS-AI-Workstation-1.0.0.dmg"
rm -f "$DMG"
hdiutil create -volname "JARVIS AI Workstation" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [[ "${1:-}" == "--sign" || "${2:-}" == "--notarize" ]]; then
  : "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity}"
  codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "build/JARVIS AI Workstation.app"
  codesign --verify --deep --strict --verbose=2 "build/JARVIS AI Workstation.app"
  rm -f "$DMG"
  hdiutil create -volname "JARVIS AI Workstation" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
fi
if [[ "${2:-}" == "--notarize" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "JARVIS_NOTARY" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
echo "Created $DMG"
