#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="build/JARVIS AI Workstation.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swift build -c release
cp ".build/release/JARVISAIWorkstation" "$APP/Contents/MacOS/JARVISAIWorkstation"
cp "Resources/components.json" "$APP/Contents/Resources/components.json"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>JARVIS AI Workstation</string>
<key>CFBundleDisplayName</key><string>JARVIS AI Workstation</string>
<key>CFBundleIdentifier</key><string>com.jarvisai.workstation</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleExecutable</key><string>JARVISAIWorkstation</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
echo "Created $APP"
