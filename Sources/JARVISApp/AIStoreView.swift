import SwiftUI

struct AIStoreView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case discover = "Discover"
        case myAI = "My AI"
        case connections = "Connections"
        case dependencies = "Dependencies"
        case activity = "Activity"\n        case health = "System Health"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .discover: "sparkles"
            case .myAI: "square.grid.2x2"
            case .connections: "point.3.connected.trianglepath.dotted"
            case .dependencies: "shippingbox"
            case .activity: "clock.arrow.circlepath"\n            case .health: "waveform.path.ecg"
            }
        }
    }

    @State private var section: Section? = .discover
    @State private var projects: [AIProject] = []
    @State private var searchText = ""
    @State private var category = "All"
    @State private var selectedProject: AIProject?
    @StateObject private var setupStore = ProjectSetupStore()
    @State private var planProject: AIProject?
    @State private var loadError: String?

    private let hardware = HardwareChecker.inspect()

    private var categories: [String] {
        ["All"] + Array(Set(projects.map(\.category))).sorted()
    }

    private var visibleProjects: [AIProject] {
        projects.filter { project in
            let matchesCategory = category == "All" || project.category == category
            let matchesSearch = searchText.isEmpty ||
                project.name.localizedCaseInsensitiveContains(searchText) ||
                project.summary.localizedCaseInsensitiveContains(searchText) ||
                project.capabilities.contains { $0.localizedCaseInsensitiveContains(searchText) }
            let matchesSection = section != .myAI || project.isKnownInstalled || setupStore.stagedIDs.contains(project.id)
            return matchesCategory && matchesSearch && matchesSection
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(Section.allCases) { item in
                    Label(item.rawValue, systemImage: item.symbol).tag(item)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("JARVIS")
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(hardware.supported ? "Apple Silicon ready" : "System compatibility check",
                          systemImage: hardware.supported ? "checkmark.seal.fill" : "exclamationmark.triangle")
                        .font(.caption.weight(.semibold))
                    Text("\(hardware.memoryGB) GB RAM · \(hardware.freeDiskGB) GB free")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        } detail: {
            Group {
                switch section ?? .discover {
                case .discover: discoverPage
                case .myAI: myAIPage
                case .connections: informationPage("Connections", subtitle: "Connect local runtimes and external providers.", items: ["Ollama · local runtime detected by the existing workstation", "API providers · configure per project, with cost and privacy disclosures", "MCP integrations · approve each server and permission separately"])
                case .dependencies: dependenciesPage\n                case .health: healthPage
                case .activity: informationPage("Activity", subtitle: "Installation history and diagnostics will appear here when project adapters are connected.", items: ["No marketplace installation has been run from this screen."])
                }
            }
            .frame(minWidth: 620, minHeight: 560)
        }
        .sheet(item: $selectedProject) { project in
            projectDetail(project)
                .frame(minWidth: 560, minHeight: 560)
        }
        .sheet(item: $planProject) { project in
            InstallPlanSheet(project: project)
                .frame(minWidth: 560, minHeight: 620)
        }
        .task { loadCatalog() }
        .tint(.cyan)
    }

    private var discoverPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(eyebrow: "JARVIS AI MARKETPLACE",
                       title: "What do you want to do?",
                       subtitle: "Discover powerful AI projects, add the ones you need, and keep their original interfaces.")
                TextField("Search projects or capabilities", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                categoryPicker
                if let loadError {
                    ContentUnavailableView("Catalogue unavailable", systemImage: "exclamationmark.triangle",
                                            description: Text(loadError))
                } else {
                    projectGrid
                }
                Text("Projects are independent third-party software. Free software does not always mean free models, API usage, or cloud hosting.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }
    }

    private var myAIPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(eyebrow: "YOUR WORKSTATION", title: "My AI",
                       subtitle: "Your installed and selected projects, each with its own UI and environment.")
                if setupStore.stagedIDs.isEmpty && projects.filter(\.isKnownInstalled).isEmpty {
                    ContentUnavailableView("Nothing added yet", systemImage: "square.grid.2x2",
                                            description: Text("Explore Discover and add projects to your setup list."))
                } else {
                    projectGrid
                }
                if !stagedIDs.isEmpty {
                    Label("\(setupStore.stagedIDs.count) project(s) in your setup list", systemImage: "list.bullet.clipboard")
                        .font(.subheadline.weight(.semibold))
                    Text("The setup list is a planning step in this build. Project-specific installation and launch adapters are not connected yet.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(28)
        }
    }

    private var dependenciesPage: some View {
        let tools = WorkstationToolDetector.detect()
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(eyebrow: "SHARED RUNTIMES", title: "Dependencies",
                       subtitle: "Read-only detection. JARVIS reuses compatible tools and will ask before installing or changing any dependency.")
                ForEach(tools) { tool in
                    HStack(spacing: 12) {
                        Image(systemName: tool.isAvailable ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(tool.isAvailable ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tool.displayName).font(.headline)
                            Text(tool.executablePath ?? "Not detected")
                                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        Spacer()
                        Text(tool.isAvailable ? "Detected" : "Missing")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tool.isAvailable ? .green : .secondary)
                    }
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
                }
                Text("Detection checks known executable locations only. A missing tool is not installed automatically.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }
    }

    private var healthPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            header(eyebrow: "DEVICE STATUS", title: "System Health",
                   subtitle: "A snapshot of the Mac before resource-intensive project installs.")
            GroupBox("Hardware") {
                VStack(alignment: .leading, spacing: 8) {
                    detailRow("Chip", hardware.chip)
                    detailRow("Architecture", hardware.architecture)
                    detailRow("macOS", hardware.macOS)
                    detailRow("Memory", "\\(hardware.memoryGB) GB")
                    detailRow("Free disk", "\\(hardware.freeDiskGB) GB")
                    detailRow("Thermal state", HardwareChecker.thermalStateDescription)
                }
            }
            if !hardware.notes.isEmpty {
                GroupBox("Recommendations") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(hardware.notes, id: \\.self) { note in
                            Label(note, systemImage: "info.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            Spacer()
        }.padding(28)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(categories, id: \.self) { item in
                    Button(item.replacingOccurrences(of: "-", with: " ").capitalized) {
                        category = item
                    }
                    .buttonStyle(.bordered)
                    .tint(category == item ? .cyan : .secondary)
                }
            }
        }
    }

    private var projectGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 14)], spacing: 14) {
            ForEach(visibleProjects) { project in
                Button { selectedProject = project } label: {
                    projectCard(project)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func projectCard(_ project: AIProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon(for: project.category))
                    .font(.title2).foregroundStyle(.cyan)
                    .frame(width: 42, height: 42)
                    .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                Spacer()
                statusLabel(project)
            }
            Text(project.name).font(.headline).foregroundStyle(.primary)
            Text(project.summary).font(.subheadline).foregroundStyle(.secondary)
                .lineLimit(3).multilineTextAlignment(.leading)
            HStack {
                Text(project.category.replacingOccurrences(of: "-", with: " ").capitalized)
                Spacer()
                Text(project.resourceClass ?? "Requirements vary")
            }
            .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.quaternary, lineWidth: 1))
    }

    private func projectDetail(_ project: AIProject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.category.replacingOccurrences(of: "-", with: " ").uppercased())
                        .font(.caption.bold()).tracking(1.2).foregroundStyle(.cyan)
                    Text(project.name).font(.largeTitle.bold())
                }
                Spacer()
                Button("Close") { selectedProject = nil }
            }
            Text(project.summary).foregroundStyle(.secondary)
            GroupBox("What it provides") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(project.capabilities, id: \.self) { Text("• " + project.capabilityLabel($0)) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Compatibility and requirements") {
                VStack(alignment: .leading, spacing: 7) {
                    detailRow("Apple Silicon", project.macOS?.appleSilicon ?? "Not verified")
                    detailRow("macOS", project.macOS?.minimum ?? "Not pinned")
                    detailRow("Resource use", project.resourceClass ?? "Not measured")
                    detailRow("Execution", project.execution)
                    detailRow("License", project.license)
                    detailRow("Dependencies", project.dependencies.joined(separator: ", ").isEmpty ? "None listed" : project.dependencies.joined(separator: ", "))
                    if let optional = project.optionalDependencies, !optional.isEmpty {
                        detailRow("Optional", optional.joined(separator: ", "))
                    }
                }
            }
            if let notes = project.integrationNotes {
                GroupBox("Important notes") {
                    Text(notes).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            HStack {
                Link(destination: project.source) { Label("Original project", systemImage: "arrow.up.right.square") }
                if let website = project.website {
                    Link(destination: website) { Label("Website", systemImage: "globe") }
                }
            }
            Spacer(minLength: 4)
            HStack {
                Button(setupStore.stagedIDs.contains(project.id) ? "Remove from setup list" : "Add to setup list") {
                    setupStore.toggle(project.id)
                }
                .buttonStyle(.borderedProminent)
                .disabled(project.isKnownInstalled)
                Button("Review install plan") { planProject = project }
                    .buttonStyle(.bordered)
                if project.isKnownInstalled {
                    Label("Already detected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            Text("Adding a project only saves it to your setup list. Installation requires a separate, reviewed approval.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private func informationPage(_ title: String, subtitle: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            header(eyebrow: "WORKSTATION", title: title, subtitle: subtitle)
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }.padding(28)
    }

    private func header(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).font(.caption.bold()).tracking(1.5).foregroundStyle(.cyan)
            Text(title).font(.largeTitle.bold())
            Text(subtitle).foregroundStyle(.secondary)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(.secondary).frame(width: 115, alignment: .leading)
            Text(value).textSelection(.enabled)
        }.font(.callout)
    }

    private func statusLabel(_ project: AIProject) -> some View {
        let label = project.isKnownInstalled ? "Detected" : (stagedIDs.contains(project.id) ? "In setup list" : "Available")
        return Text(label).font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }

    private func icon(for category: String) -> String {
        switch category {
        case "image-video": "photo.stack"
        case "voice-audio": "waveform"
        case "agents": "brain"
        case "reverse-engineering": "magnifyingglass"
        case "assistants": "person.wave.2"
        case "models": "cpu"
        default: "sparkles"
        }
    }

    private func loadCatalog() {
        guard let url = Bundle.main.url(forResource: "ai-project-catalog", withExtension: "json") else {
            loadError = "The AI project catalogue was not included in the application bundle."
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let catalogue = try JSONDecoder().decode(AIProjectCatalog.self, from: data)
            projects = catalogue.projects.filter { $0.installStatus != "alias" }
        } catch {
            loadError = "Could not read the catalogue: \(error.localizedDescription)"
        }
    }
}


struct InstallPlanSheet: View {
    let project: AIProject
    @Environment(\.dismiss) private var dismiss
    private var plan: ProjectInstallPlan { ProjectInstallPlanner.makePlan(for: project) }
    private var tools: [DetectedTool] { WorkstationToolDetector.detect() }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("INSTALLATION REVIEW").font(.caption.bold()).tracking(1.3).foregroundStyle(.cyan)
                    Text(project.name).font(.largeTitle.bold())
                }
                Spacer()
                Button("Close") { dismiss() }
            }
            if plan.canInstall {
                Label("Ready for verification", systemImage: "checkmark.seal")
                    .foregroundStyle(.green).font(.headline)
            } else {
                Label("Installation blocked pending verification", systemImage: "lock.fill")
                    .foregroundStyle(.orange).font(.headline)
            }
            GroupBox("Host tools detected") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tools) { tool in
                        HStack {
                            Image(systemName: tool.isAvailable ? "checkmark.circle.fill" : "minus.circle")
                                .foregroundStyle(tool.isAvailable ? .green : .secondary)
                            Text(tool.displayName)
                            Spacer()
                            Text(tool.executablePath ?? "Not detected")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            if !plan.blockers.isEmpty {
                GroupBox("Why installation is blocked") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.blockers, id: \.self) { item in
                            Label(item, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            if !plan.warnings.isEmpty {
                GroupBox("Review before proceeding") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(plan.warnings, id: \.self) { item in
                            Label(item, systemImage: "info.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            GroupBox("Planned workflow — no commands run") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(plan.actions.enumerated()), id: \.offset) { index, action in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).").foregroundStyle(.secondary).monospacedDigit()
                            Text(action).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Text("JARVIS will not run install scripts, change system dependencies, or modify agent configuration until a pinned release, compatibility checks, and an explicit approval flow are implemented.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Close review") { dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

private extension AIProject {
    func capabilityLabel(_ value: String) -> String {
        value.replacingOccurrences(of: "-", with: " ").capitalized
    }
}
