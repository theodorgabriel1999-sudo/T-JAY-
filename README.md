# JARVIS AI Workstation 1.0

Native SwiftUI workstation bootstrapper for Apple Silicon (M1–M5), macOS 14+.

## MVP contents
- Hardware preflight (arm64, macOS, RAM, free disk).
- Guided component selection and one-click recommended profile.
- Versioned JSON component manifest.
- Restricted command runner; no shell interpolation or arbitrary command text.
- Local installer log.
- App bundle and DMG build scripts.

## Build on a Mac
Requires Swift 5.9+ and Xcode Command Line Tools.

```sh
git clone https://github.com/theodorgabriel1999-sudo/T-JAY-.git
cd T-JAY-
swift build
swift run
bash scripts/build-app.sh
bash scripts/build-dmg.sh
```

DMG output: `dist/JARVIS-AI-Workstation-1.0.0.dmg`.

For trusted public distribution, use your own Developer ID Application certificate and Apple notarization credentials. Never commit signing secrets. See docs/RELEASE_CHECKLIST.md.

## Important limitations
Homebrew must already exist at `/opt/homebrew/bin/brew`. The MVP does not install Homebrew or execute remote scripts. Component compatibility varies by macOS release. The app source is not yet a signed/notarized release.

Third-party software retains its own licenses and commercial-use terms. See THIRD_PARTY_NOTICES.md. Clear the JARVIS name for trademark use before selling.

## License
JARVIS project source: MIT. This does not relicense third-party software.
