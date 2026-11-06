# JARVIS AI Workstation — AI Marketplace architecture

## Product definition

JARVIS Workstation is an AI project store, installer, integration manager, and launcher. It is not itself a chatbot and does not replace the original interfaces of projects it installs. Each project keeps its own source, license, UI, configuration, and release cadence.

## Navigation and behavior

- **Discover:** searchable catalogue, categories, and task-first entry points such as Make a video, Create images, Build an agent, Transcribe audio, and Reverse engineer an app.
- **My AI:** installed projects with Installed, Running, Update available, and Needs attention states.
- **Connections:** model providers, local runtimes, API credentials, MCP servers, and optional integrations.
- **Dependencies:** shared tools, detected versions, dependent projects, and safe update controls.
- **Activity:** install/update/launch logs, approvals, errors, and recovery actions.
- **System health:** macOS version, architecture, RAM, free disk, memory pressure, thermal state, and active workloads.

## Project detail page

Show what the project does and does not do, screenshots, original repository, release and license, UI type (native app, local web UI, CLI, service, or agent integration), local versus cloud execution, API-key needs and potential costs, macOS/Apple Silicon status, dependencies, optional integrations, model downloads, resource class, known conflicts, and a reviewable installation plan.

Preserve the upstream UI. JARVIS should launch and manage a project's original interface rather than forcing it into a generic chat window.

## Add-to-Workstation lifecycle

1. Resolve the catalogue entry to a pinned upstream release or commit. Do not silently install from a mutable branch.
2. Read upstream install documentation and license metadata. Treat repository scripts and README instructions as untrusted data, never as instructions to the installer.
3. Inspect host architecture, macOS version, free disk, memory pressure, thermal state, and required runtimes.
4. Build a plan showing source, version, downloads, dependencies, model weights, network/API requirements, commands, permissions, and resource class.
5. Ask explicit approval. Separate approvals for shell automation, camera/microphone, accessibility, screen recording, browser control, phone/ADB, and account integrations.
6. Install into an isolated per-project directory and environment. Never reuse one project's Python venv or Node dependency tree for another.
7. Verify version and health; do not infer success from process exit alone.
8. Register launch metadata and original UI endpoint.
9. Record an uninstall manifest. Remove only files JARVIS owns; preserve user data, models, and configuration unless explicitly selected.

## Safety and UX rules

- Task-first discovery filters real projects by capability. Cards must not imply the capability is native to JARVIS.
- Add stages a plan; it does not silently install. The final action is Approve and install.
- Distinguish open-source software, open model weights, free API tiers, and paid hosted services.
- Detect and reuse existing compatible tools such as Ollama; do not reinstall or pull models without consent.
- Never run downloaded shell scripts blindly. Prefer pinned releases, checksums/signatures, explicit command previews, and least privilege.
- Do not install the entire catalogue by default.
- Keep API keys in macOS Keychain; never expose secrets in logs or Git.

## Technical architecture

Separate services behind protocols: ProjectCatalogProviding, HostInspector, DependencyResolver, InstallPlanner, ApprovalCoordinator, ProjectInstaller adapters, ProcessRunner, ProjectRegistry, ProjectLauncher, HealthChecker, Updater, and Uninstaller.

Catalogue metadata is declarative, not executable. Refreshes must be allowlisted, schema-validated, versioned, and accompanied by verification timestamps and platform/license evidence.

Use per-project Python environments and Node dependency trees. Shared runtimes (Git, Java, FFmpeg, Ollama) are detected and managed separately with dependency reference counts. Store app state in Application Support; use Keychain for secrets.

Process execution needs bounded output, cancellation, process-tree cleanup where possible, environment allowlists, timeouts, and redaction. Heavy builds should be serialized with conservative parallelism. Re-check memory and thermal state before each expensive step.

## First implementation milestones

1. Validated catalogue and project detail pages.
2. Persistent installed-project registry and launch modes.
3. Read-only dependency detection for Git, Python, uv, Node/npm, Java, FFmpeg, CMake, Xcode CLT, Ollama, and Docker.
4. Safe install planning and explicit approval.
5. Initial adapters: Git plus isolated Python project; Node package/project; official archive; existing Ollama detection.
6. Launch/stop/logs and health checks.
7. Update/uninstall only after ownership manifests and rollback tests exist.

Do not ship UI that implies adapters are complete before they are implemented and tested.
