import Foundation
import Combine
@MainActor final class InstallerViewModel: ObservableObject {
    enum InstallMode { case guided, oneClick }
    @Published var components: [Component] = []
    @Published var selectedIDs: Set<String> = []
    @Published var states: [String: InstallState] = [:]
    @Published var logLines: [String] = []
    @Published var isRunning = false
    @Published var mode: InstallMode = .guided
    let hardware = HardwareChecker.inspect()
    private let runner = SafeCommandRunner()

    init() { loadManifest() }
    var selectedComponents: [Component] { components.filter { selectedIDs.contains($0.id) } }

    func loadManifest() {
        let bundled = Bundle.main.url(forResource: "components", withExtension: "json")
        let development = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/components.json")
        guard let url = bundled ?? (FileManager.default.fileExists(atPath: development.path) ? development : nil),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(ComponentManifest.self, from: data) else {
            log("ERROR: component manifest could not be loaded."); return
        }
        components = manifest.components
        selectedIDs = Set(components.filter(\\.recommended).map(\\.id))
        log("JARVIS \\(manifest.productVersion) catalogue loaded.")
    }
    func selectRecommended() { selectedIDs = Set(components.filter(\\.recommended).map(\\.id)) }

    func installSelected() async {
        guard !isRunning else { return }
        guard hardware.supported else { log("Blocked: unsupported system."); return }
        guard !selectedComponents.isEmpty else { log("Select at least one component."); return }
        isRunning = true
        defer { isRunning = false }
        log("Preflight passed. Starting installation queue.")
        for item in selectedComponents {
            states[item.id] = .checking
            if item.requiresHomebrew && !runner.executableExists("/opt/homebrew/bin/brew") {
                states[item.id] = .failed("Homebrew missing at /opt/homebrew/bin/brew.")
                log("\\(item.name): install Homebrew separately, then retry.")
                continue
            }
            states[item.id] = .installing
            do {
                let result = try await runner.run(item.executable, item.arguments)
                if !result.isEmpty { log(result) }
                let verification = try await runner.run(item.verificationExecutable, item.verificationArguments)
                states[item.id] = .succeeded
                log("\\(item.name) verified: \\(verification)")
            } catch {
                states[item.id] = .failed(error.localizedDescription)
                log("\\(item.name) failed: \\(error.localizedDescription)")
            }
        }
        log("Installation queue finished.")
    }
    func log(_ message: String) {
        let line = "[\\(Date.now.formatted(date: .omitted, time: .standard))] \\(message)"
        logLines.append(line)
        if logLines.count > 400 { logLines.removeFirst(logLines.count - 400) }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JARVIS AI Workstation", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("installer.log")
        let data = (line + "\\n").data(using: .utf8)!
        if FileManager.default.fileExists(atPath: file.path), let handle = try? FileHandle(forWritingTo: file) {
            try? handle.seekToEnd(); try? handle.write(contentsOf: data); try? handle.close()
        } else { try? data.write(to: file) }
    }
}
private struct SafeCommandRunner {
    func executableExists(_ path: String) -> Bool { FileManager.default.isExecutableFile(atPath: path) }
    func run(_ executable: String, _ arguments: [String]) async throws -> String {
        try await Task.detached(priority: .utility) {
            guard executable == "/opt/homebrew/bin/brew" else { throw RunnerError.disallowed }
            guard FileManager.default.isExecutableFile(atPath: executable) else { throw RunnerError.missing }
            let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
            try p.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            guard p.terminationStatus == 0 else { throw RunnerError.failed(output) }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }
    enum RunnerError: LocalizedError {
        case disallowed, missing, failed(String)
        var errorDescription: String? {
            switch self {
            case .disallowed: return "Executable is not allowlisted."
            case .missing: return "Homebrew executable not found."
            case .failed(let output): return output.isEmpty ? "Installer returned a non-zero exit code." : output
            }
        }
    }
}
