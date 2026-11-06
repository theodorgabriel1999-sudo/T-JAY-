import Foundation
import Combine

struct ProjectInstallPlan {
    let projectID: String
    let projectName: String
    let destination: URL
    let actions: [String]
    let blockers: [String]
    let warnings: [String]

    var canInstall: Bool { blockers.isEmpty }
}

struct DetectedTool: Identifiable {
    let id: String
    let displayName: String
    let executablePath: String?
    let isAvailable: Bool
}

enum WorkstationToolDetector {
    static func detect() -> [DetectedTool] {
        let paths: [(String, String, [String])] = [
            ("git", "Git", ["/usr/bin/git", "/opt/homebrew/bin/git"]),
            ("python3", "Python 3", ["/usr/bin/python3", "/opt/homebrew/bin/python3"]),
            ("uv", "uv", ["/opt/homebrew/bin/uv", "/usr/local/bin/uv"]),
            ("node", "Node.js", ["/opt/homebrew/bin/node", "/usr/local/bin/node"]),
            ("npm", "npm", ["/opt/homebrew/bin/npm", "/usr/local/bin/npm"]),
            ("java", "Java", ["/usr/bin/java", "/opt/homebrew/bin/java"]),
            ("ffmpeg", "FFmpeg", ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]),
            ("ollama", "Ollama", ["/usr/local/bin/ollama", "/opt/homebrew/bin/ollama"])
        ]
        return paths.map { id, name, candidates in
            let found = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            return DetectedTool(id: id, displayName: name, executablePath: found, isAvailable: found != nil)
        }
    }
}

enum ProjectInstallPlanner {
    static func makePlan(for project: AIProject) -> ProjectInstallPlan {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = appSupport.appendingPathComponent("JARVIS AI Workstation/Projects", isDirectory: true)
        let destination = root.appendingPathComponent(project.id, isDirectory: true)

        if project.isKnownInstalled {
            return ProjectInstallPlan(
                projectID: project.id, projectName: project.name, destination: destination,
                actions: ["Verify the existing installation and register its launch information."],
                blockers: [], warnings: ["JARVIS has detected this project as already installed. It will not reinstall it."]
            )
        }

        var blockers: [String] = []
        var warnings: [String] = []

        blockers.append("This catalogue entry does not yet pin a verified upstream release or immutable commit. JARVIS will not install from a moving branch.")
        if project.macOS?.appleSilicon == nil ||
            project.macOS?.appleSilicon?.localizedCaseInsensitiveContains("unverified") == true ||
            project.macOS?.appleSilicon?.localizedCaseInsensitiveContains("research") == true ||
            project.macOS?.appleSilicon?.localizedCaseInsensitiveContains("candidate") == true ||
            project.macOS?.appleSilicon?.localizedCaseInsensitiveContains("verify") == true ||
            project.macOS?.appleSilicon?.localizedCaseInsensitiveContains("needs") == true {
            blockers.append("Apple Silicon compatibility has not been verified for this project and release.")
        }
        if project.reviewRequired == true {
            warnings.append("Upstream install instructions and third-party dependency terms require human review.")
        }
        if project.id == "rea" {
            warnings.append("REA's documented setup command can modify agent configuration. JARVIS will not run it automatically.")
        }
        if project.id == "jarvis-ai-assistant-user-project" {
            blockers.append("The upstream project lists Windows as its primary platform; macOS support is unverified.")
        }
        if project.resourceClass?.localizedCaseInsensitiveContains("heavy") == true {
            warnings.append("This project may use substantial memory, disk space, and sustained compute. Re-check thermal and memory pressure before installation.")
        }

        let actions = [
            "Create an isolated project directory at \(destination.path).",
            "Fetch only a verified, pinned upstream release or commit.",
            "Review the upstream manifest and dependency install scripts before executing them.",
            "Create a project-specific environment; do not share Python or Node dependencies with other projects.",
            "Verify the installed version and register the project's original UI or launch command."
        ]

        return ProjectInstallPlan(
            projectID: project.id, projectName: project.name, destination: destination,
            actions: actions, blockers: blockers, warnings: warnings
        )
    }
}

@MainActor
final class ProjectSetupStore: ObservableObject {
    @Published private(set) var stagedIDs: Set<String> = []
    private let storageKey = "jarvis.marketplace.stagedProjectIDs"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            stagedIDs = Set(ids)
        }
    }

    func toggle(_ id: String) {
        if stagedIDs.contains(id) { stagedIDs.remove(id) }
        else { stagedIDs.insert(id) }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Array(stagedIDs).sorted()) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
