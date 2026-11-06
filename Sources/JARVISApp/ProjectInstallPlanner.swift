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
    var canFetchSource: Bool {
        !projectID.isEmpty &&
        !blockers.contains(where: { $0.localizedCaseInsensitiveContains("immutable commit") })
    }
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

        let hasPinnedCommit = project.pinnedCommit?.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil
        if !hasPinnedCommit {
            blockers.append("This catalogue entry does not yet pin a verified upstream release or immutable commit. JARVIS will not install from a moving branch.")
        }
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
            hasPinnedCommit
                ? "Fetch exact upstream commit \(project.pinnedCommit!)."
                : "Resolve and verify an immutable upstream release or commit before fetching.",
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


enum ProjectSourceInstaller {
    enum InstallError: LocalizedError {
        case unsupportedSource
        case invalidCommit
        case destinationExists
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedSource: return "Only HTTPS GitHub repositories are supported by this source downloader."
            case .invalidCommit: return "The catalogue does not contain a valid 40-character commit pin."
            case .destinationExists: return "A project folder already exists at the destination. Remove or back it up before downloading again."
            case .commandFailed(let output): return output.isEmpty ? "Git could not complete the source download." : output
            }
        }
    }

    static func downloadPinnedSource(for project: AIProject) async throws -> URL {
        guard project.source.scheme?.lowercased() == "https",
              project.source.host?.lowercased() == "github.com" else {
            throw InstallError.unsupportedSource
        }
        guard let commit = project.pinnedCommit,
              commit.range(of: "^[0-9a-fA-F]{40}$", options: .regularExpression) != nil else {
            throw InstallError.invalidCommit
        }

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = support.appendingPathComponent("JARVIS AI Workstation/Projects", isDirectory: true)
        let destination = root.appendingPathComponent(project.id, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw InstallError.destinationExists
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let sourceURL = project.source.absoluteString
        let destinationPath = destination.path
        let checkedOutPath = try await Task.detached(priority: .utility) {
            do {
                try runGit(["clone", "--filter=blob:none", "--no-checkout", sourceURL, destinationPath])
                try runGit(["-C", destinationPath, "checkout", "--detach", commit])
                return destinationPath
            } catch {
                try? FileManager.default.removeItem(atPath: destinationPath)
                throw error
            }
        }.value
        return URL(fileURLWithPath: checkedOutPath)
    }

    private static func runGit(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            throw InstallError.commandFailed("Could not start /usr/bin/git: \(error.localizedDescription)")
        }
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: output, encoding: .utf8) ?? "Git exited with status \(process.terminationStatus)."
            throw InstallError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
