# Shared dependency registry

This is a planning registry, not an instruction to install every tool. Detect first, reuse compatible versions, and install only when a selected project requires them.

| Dependency | Used by | Purpose | Policy |
|---|---|---|---|
| Git | Most source-based projects, REA, Ghidra source workflows | Clone and update source | Essential baseline; detect Apple/Xcode or Homebrew install |
| Python 3 | JARVIS Assistant, ComfyUI, Open WebUI, tooling | Python runtime | Per-project isolated environments; never use system Python packages |
| uv | Python projects | Environment and package management | Preferred Python environment manager; pin requirements |
| Node.js + npm | REA, OpenClaw, JavaScript tooling | Runtime and package manager | Respect project version constraints; isolate package trees |
| Java JDK | Ghidra | JVM runtime | Match selected Ghidra release; current upstream README says JDK 25 |
| FFmpeg | Audio/video workflows and media conversion | Decode/encode media | Optional shared utility; disclose build/source |
| Xcode Command Line Tools | Native builds and C/C++ projects | Clang, SDKs, make | Reuse existing system installation; avoid unnecessary builds |
| CMake | whisper.cpp and native dependencies | Configure native builds | Install only for source-build path |
| Ninja | Native builds | Build backend | Optional; conservative parallelism |
| Docker | Containerized services | Runtime isolation | Optional; adds disk/RAM overhead and background services |
| ADB | Optional Android integration in JARVIS Assistant | Android device bridge | Explicit opt-in; USB debugging has security implications |
| Ollama | Local model serving | Local model runtime/API | Detect existing install; do not reinstall or pull models without consent |
| Browser runtime | Browser automation and web agents | Controlled browser session | Install only for selected integration; isolate profile and permissions |

## Dependency behavior

- Record detected path, version, architecture, source, and whether JARVIS manages it.
- Distinguish required from optional dependencies.
- Check version constraints against the selected project release.
- Explain conflicts before changing a shared runtime.
- Never upgrade a shared dependency silently because one project requests it.
- Use a project-pinned runtime when a shared version would conflict.
- Keep logs redacted and avoid passing credentials as command-line arguments.
- Check reference counts before offering to uninstall a shared dependency.
