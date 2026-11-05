# JARVIS AI Workstation 1.0.1 — reliability rebuild

Native SwiftUI workstation bootstrapper for Apple Silicon (M1–M5), macOS 14+.

## What changed in 1.0.1

- Stream Homebrew output into the installer activity view as it arrives.
- Show the active install/verification step without inventing a percentage.
- Add a Cancel action and stop starting subsequent components after cancellation.
- Surface macOS thermal state and defer the next install step when thermal pressure is serious or critical.
- Explain that Homebrew may compile dependencies and use substantial CPU.
- Add timestamped DMG build stages and validate the generated disk image.

## Important limitations

This is a reliability-development build, not yet a validated consumer release. Cancellation sends a termination request to the active Homebrew process; Homebrew may have spawned child build tools, and package-manager state can be partial after cancellation. Inspect Homebrew state before retrying. Thermal state is macOS's qualitative thermal-pressure signal, not a numeric CPU temperature. No numeric CPU temperature or live CPU percentage is claimed.

Homebrew must already exist at `/opt/homebrew/bin/brew`. Component compatibility varies by macOS release. The app is not signed or notarized by default.

## Build on your Mac

Requires Swift 5.9+ and Xcode Command Line Tools.

```sh
git clone https://github.com/theodorgabriel1999-sudo/T-JAY-.git
cd T-JAY-
git checkout reliability-1.0.1
swift build
swift run
bash scripts/build-dmg.sh
```

The build script prints its stages. Expected output:
`dist/JARVIS-AI-Workstation-1.0.1.dmg`.

Before replacing an existing app, quit JARVIS. The new DMG is an unsigned development build unless you explicitly configure Developer ID signing and notarization. For trusted public distribution, use your own Developer ID Application certificate and Apple notarization credentials. Never commit signing secrets. See docs/RELEASE_CHECKLIST.md.

Third-party software retains its own licenses and commercial-use terms. See THIRD_PARTY_NOTICES.md. Clear the JARVIS name for trademark use before selling.

## License

JARVIS project source: MIT. This does not relicense third-party software.
