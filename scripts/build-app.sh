#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="build/JARVIS AI Workstation.app"
step() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"; }
step "Preparing release build"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
step "Compiling Swift release executable"
swift build -c release
EXECUTABLE=".build/release/JARVISAIWorkstation"
if [[ ! -x "$EXECUTABLE" ]]; then
  echo "ERROR: expected executable not found: $EXECUTABLE" >&2
  exit 1
fi
step "Assembling application bundle"
cp "$EXECUTABLE" "$APP/Contents/MacOS/JARVISAIWorkstation"
cp "Resources/components.json" "$APP/Contents/Resources/components.json"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>JARVIS AI Workstation</string>
<key>CFBundleDisplayName</key><string>JARVIS AI Workstation</string>
<key>CFBundleIdentifier</key><string>com.jarvisai.workstation</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleShortVersionString</key><string>1.0.2</string>
<key>CFBundleExecutable</key><string>JARVISAIWorkstation</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
test -x "$APP/Contents/MacOS/JARVISAIWorkstation"
test -f "$APP/Contents/Resources/components.json"
step "Application bundle created: $APP"
