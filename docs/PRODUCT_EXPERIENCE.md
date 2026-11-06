# JARVIS AI Workstation — Product Experience

## Product definition

JARVIS is a local-first AI project marketplace, installer, integration manager, launcher, and maintenance console. It is not itself a general-purpose AI assistant and does not replace the user interfaces of the projects it manages.

The product promise is: **find the right AI tool for a task, understand what it needs, install it safely, connect it when useful, and open its own experience from one place.**

## Primary navigation

- **Discover** — capability-led catalogue, featured projects, search, filters, and curated collections.
- **My Tools** — installed projects, versions, health, running state, updates, repair, launch, and uninstall.
- **Connections** — integrations between projects, model providers, local services, APIs, MCP servers, and workflows.
- **Activity** — install/update/repair history, command output, permission decisions, and diagnostics.
- **System** — hardware compatibility, disk usage, thermal and memory health, shared runtimes, and security settings.

## Discover by outcome

The home screen starts with the user's goal, not a wall of repository names:

- Make videos
- Create images and designs
- Work with voice and audio
- Build AI agents
- Code and build software
- Research and work with documents
- Automate workflows
- Reverse engineer software and binaries

Each capability page shows curated tools, what each does well, whether it runs locally or uses a cloud/API, and the trade-offs. Search and filters include Local-ready, Cloud/API, Free software, Open weights, Resource-heavy, and External hardware.

## Project detail page

Every project page should include:

1. Name, icon, screenshots, short plain-language summary, and official repository/site.
2. Capability tags and example workflows.
3. Project license and model/asset licenses as separate fields. Explain source-available versus OSI-approved open source.
4. Execution mode: local, cloud/API, hybrid, or external hardware.
5. macOS and Apple Silicon compatibility, last verification date, supported versions, and confidence.
6. Dependencies, shared runtimes, storage estimate, RAM/compute notes, and thermal impact.
7. Install, configure, connect, launch, update, repair, and uninstall actions where supported.
8. Permissions and security review: network access, filesystem scope, shell execution, browser control, credentials, background services, and exposed ports.
9. Clear costs: free software does not necessarily mean free models, API usage, hosting, or hardware.

The primary action changes by state: **Install**, **Configure**, **Connect**, **Open**, **Update**, or **Repair**.

## Install flow

1. Resolve the selected project's manifest and pinned source revision.
2. Inspect the machine and already-installed dependencies.
3. Build a dependency graph and identify reusable shared runtimes.
4. Show a plan: new downloads, versions, commands, disk estimate, permissions, network access, and any paid/API requirements.
5. Ask for explicit approval before making changes.
6. Download from the official source, verify checksums/signatures where available, and install in an isolated project environment.
7. Run project-specific health checks and record installed state persistently.
8. Offer to configure or connect the project; do not force integrations.

Do not execute remote shell scripts blindly. Do not elevate privileges automatically. Use project-specific virtual environments for Python, pinned Node environments where needed, and isolated data/config directories. Shared runtimes must be version-aware and must not silently break other projects.

## Connections are separate from installation

A connection is a declared adapter between two installed projects or services. It has a source, destination, capability, endpoint/auth method, required permissions, compatibility range, and a test/health check.

Examples:
- Ollama provides local model inference to a compatible agent or UI.
- ComfyUI exposes image-generation workflows to a compatible client.
- A speech-to-text engine can feed transcripts into a workflow.
- An agent can call a workflow only after the user grants the required tool permissions.

Never imply that two tools integrate merely because both are AI projects. Only show connections verified by official documentation, a maintained adapter, or a tested protocol.

## Preserve each project's identity

JARVIS is the control plane, not a replacement UI. Projects with their own desktop or web UI remain independent. Launch them in their native app or open their local web UI in the user's browser. Do not embed, fork, or rebrand their interfaces unless the project explicitly supports that integration.

The JARVIS AI Assistant repository supplied by the user is to be catalogued as an independent project with its own UI. Its installation and launch procedure must be inspected and tested before it is marked one-click-ready.

The exact repository for the user's "Reverse Engineering Everything" project is still awaiting confirmation. Do not substitute a similarly named repository.

## Hardware-aware recommendations

For the user's current Apple Silicon M2 Pro with 16 GB RAM, prioritize lightweight local tools and sequential workloads. Show warnings before large model downloads, GPU-heavy generation, video workflows, or multiple concurrent agents. Do not promise that a model or workflow will run well merely because it installs.

The installer should distinguish:
- **Local-ready** — supported local workflow on detected hardware.
- **Resource-heavy** — may work, but has material RAM, disk, GPU, or thermal demands.
- **Cloud/API** — requires external service credentials or usage fees.
- **External hardware** — needs a supported accelerator or separate machine.
- **Needs verification** — project or version compatibility has not yet been tested.

## Persistent project registry

Persist project records outside the app bundle. Track source URL, pinned revision, installed version, install location, environment path, dependencies, launch method, health status, last check, user permissions, connection records, and install history. The bundled catalogue is discovery metadata; installed state is a separate local registry.

## MVP implementation sequence

1. Replace the current two-component manifest concept with a versioned project catalogue and richer project metadata.
2. Build the Discover and My Tools screens using catalogue records.
3. Add project detail and a human-readable installation plan.
4. Add persistent install records and safe project-specific runners.
5. Add launch adapters for native apps, CLI services, and local web UIs.
6. Add a separate Connections registry and verified integration adapters.
7. Add update, repair, uninstall, health checks, and diagnostics.
8. Add signed catalogue updates and project verification before enabling remote catalogue delivery.

The current reliability installer is a useful safety foundation, but it is not yet the complete marketplace or project manager described here.
