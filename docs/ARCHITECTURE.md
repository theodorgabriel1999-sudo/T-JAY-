# Architecture

- **SwiftUI**: dashboard, hardware status, guided/one-click mode, component choices, plan confirmation and logs.
- **View model**: loads the JSON manifest and runs the selected queue.
- **Hardware preflight**: arm64, macOS 14+, RAM and free storage.
- **Manifest**: versioned component metadata and fixed executable/argument arrays.
- **Safe runner**: launches only the allowlisted Homebrew binary; no shell, eval or user-entered commands.
- **Logging**: Application Support/JARVIS AI Workstation/installer.log.

## Safety and known MVP limitations
Homebrew must already be installed at /opt/homebrew/bin/brew. The MVP intentionally avoids remote shell scripts and automatic privilege escalation. The command runner is restricted to a fixed executable and the app runs manifest-supplied fixed argument arrays. Remote manifests must not be accepted without signature verification.

Before commercial release add cancellation/timeouts, streaming output, rollback, uninstall/repair, dependency graphs, artifact checksum/signature verification, robust macOS compatibility metadata, accessibility, privacy documentation and thorough clean-machine tests. This MVP is a source foundation, not a production-certified installer.
