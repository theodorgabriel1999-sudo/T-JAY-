# Plugin marketplace MVP

## Purpose

JARVIS is the control plane for independently maintained AI applications and developer tools. It discovers, evaluates, installs, configures, connects, launches, updates, repairs, and removes projects. It does not pretend to be the AI model or replace a project's own UI.

## App navigation

- **Discover**: browse by outcome and capability.
- **My Tools**: installed projects, versions, health, running state, and actions.
- **Connections**: verified adapters between tools, runtimes, and services.
- **Activity**: install plans, approvals, logs, updates, repairs, and diagnostics.
- **System**: hardware readiness, disk use, thermal/memory state, shared runtimes, and security.

## Discover categories

Create (image/video/audio), Voice & Audio, Agents, Coding & Build, Research & Documents, Automation, and Reverse Engineering.

Each card shows project name, original publisher, concise purpose, representative screenshots, capability tags, execution mode, compatibility confidence, resource class, license status, and cost model. Search filters include Local-ready, Cloud/API, Open-source, Open weights, Resource-heavy, and Needs verification.

## Project detail and primary action

Show official repository/site, project and model/asset licenses separately, supported macOS versions, Apple Silicon status, last verification date, dependencies, disk/RAM/compute notes, API/hosting charges, permissions, known limitations, screenshots, and source links.

Primary action is state-aware: **Install**, **Configure**, **Connect**, **Open**, **Update**, or **Repair**. If a project has its own UI, launch that UI (native app, browser, or local web UI). Do not iframe, fork, rebrand, or rebuild it by default.

## Install journey

1. Resolve a curated manifest and pinned source/version.
2. Inspect the machine and existing tools; detect reusable dependencies.
3. Resolve a dependency graph and conflicts without modifying the system.
4. Present a human-readable plan: downloads, versions, disk estimate, commands, permissions, network access, API credentials, and paid-service caveats.
5. Require explicit approval.
6. Acquire from official sources; verify checksums/signatures where available.
7. Install in an isolated project environment (Python venv/uv, project-scoped Node environment, or native app bundle).
8. Run a project-specific health check and persist the result.
9. Offer optional connections; never silently edit another tool's configuration.

Never run an opaque remote shell script automatically, never elevate privileges silently, and never store secrets in the catalogue. Commands must be visible and auditable.

## Connections

A connection is a separately approved, versioned adapter with source, destination, capability, protocol, endpoint, auth method, compatibility range, required permissions, and health check. Only advertise integrations supported by official docs, a maintained adapter, or a test in this app. Installing two AI tools does not imply that they integrate.

Examples: Ollama as a local model provider; ComfyUI as a media workflow backend; speech-to-text output feeding an automation workflow; REA registered as an MCP server for a supported agent. Ask before changing the destination project's config and preserve backups.

## Independent UIs

JARVIS manages projects; each project owns its product experience. For example, JARVIS AI Assistant is a separate assistant with a web UI and should open in that UI after its runtime is configured. REA is an MCP/tooling integration, not a generic video or image plugin. Ghidra remains its own desktop reverse-engineering application.

## Installed-project registry

Persist outside the app bundle: project ID, official source, pinned revision, installed version, install path, environment path, dependency versions, launch adapter, health state, last health check, granted permissions, connection IDs, and install/update history. Keep catalogue metadata separate from local installation state.

## Hardware-aware behavior

On a 16 GB Apple Silicon machine, prefer lightweight local tools and sequential workloads. Warn before large model downloads, GPU-heavy generation, video workflows, or concurrent agents. Never promise performance based solely on successful installation. Show estimated disk/RAM needs and let users defer heavy projects.

## MVP build order

1. Load the curated project catalogue into Discover.
2. Add search, capability categories, filters, and project detail.
3. Add compatibility/dependency inspection and a reviewable install plan.
4. Add explicit approval and isolated install runners.
5. Add persistent My Tools registry and launch adapters.
6. Add verified Connections and per-connection permissions.
7. Add update, repair, uninstall, diagnostics, and activity history.
8. Add signed catalogue updates and automated manifest validation.

## Acceptance criteria

- A user can find a tool by desired outcome without knowing its repository name.
- Every project detail links to its official source and clearly distinguishes verified facts from unknowns.
- Install never begins before the user approves a concrete plan.
- A Python project's dependencies do not pollute another project's environment.
- Existing project UIs remain intact and launchable.
- Connections are visible, optional, permission-scoped, and health-checked.
- The user can inspect, cancel where safe, and diagnose every managed operation.
