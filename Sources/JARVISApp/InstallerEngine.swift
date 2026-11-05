import Foundation
import Combine

@MainActor
final class InstallerViewModel: ObservableObject {
    enum InstallMode { case guided, oneClick }

    @Published var components: [Component] = []
    @Published var selectedIDs: Set<String> = []
    @Published var states: [String: InstallState] = [:]
    @Published var logLines: [String] = []
    @Published var isRunning = false
    @Published var cancelRequested = false
    @Published var mode: InstallMode = .guided
    @Published var currentStep = "Ready"
    @Published var currentOutput = ""
    @Published var thermalState = HardwareChecker.thermalStateDescription

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
        selectedIDs = Set(components.filter(\.recommended).map(\.id))
        log("JARVIS \(manifest.productVersion) catalogue loaded.")
    }

    func selectRecommended() { selectedIDs = Set(components.filter(\.recommended).map(\.id)) }

    func cancelInstallation() {
        guard isRunning else { return }
        cancelRequested = true
        currentStep = "Stopping active installer…"
        log("Cancellation requested. Sending a termination request to the active Homebrew process.")
        runner.cancel()
    }

    func installSelected() async {
        guard !isRunning else { return }
        guard hardware.supported else { log("Blocked: unsupported system."); return }
        guard !selectedComponents.isEmpty else { log("Select at least one component."); return }

        runner.resetCancellation()
        isRunning = true
        cancelRequested = false
        currentOutput = ""
        defer {
            isRunning = false
            currentStep = cancelRequested ? "Cancelled" : "Finished"
            runner.resetCancellation()
        }

        log("Preflight passed. Homebrew may compile dependencies and use substantial CPU.")
        log("Thermal state at start: \(thermalState).")
        for item in selectedComponents {
            if cancelRequested { break }
            thermalState = HardwareChecker.thermalStateDescription
            if HardwareChecker.shouldDeferNextInstallStep {
                states[item.id] = .paused("Deferred because macOS reports high thermal pressure.")
                currentStep = "Paused for cooling"
                log("Safety pause: \(item.name) was not started because macOS reports \(thermalState). Let the Mac cool, then retry.")
                break
            }

            states[item.id] = .checking
            currentStep = "Checking \(item.name)"
            if item.requiresHomebrew && !runner.executableExists("/opt/homebrew/bin/brew") {
                states[item.id] = .failed("Homebrew missing at /opt/homebrew/bin/brew.")
                log("\(item.name): install Homebrew separately, then retry.")
                continue
            }

            states[item.id] = .installing
            currentStep = "Installing \(item.name) — waiting for package manager"
            log("Starting \(item.name). Output will appear below as the process emits it.")
            do {
                let result = try await runner.run(item.executable, item.arguments) { [weak self] chunk in
                    Task { @MainActor in
                        guard let self else { return }
                        self.currentStep = "Installing \(item.name)"
                        self.currentOutput = String((self.currentOutput + chunk).suffix(5000))
                        self.log(chunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                if !result.isEmpty { log(result) }
                if cancelRequested { break }
                currentStep = "Verifying \(item.name)"
                let verification = try await runner.run(item.verificationExecutable, item.verificationArguments) { [weak self] chunk in
                    Task { @MainActor in self?.log(chunk.trimmingCharacters(in: .whitespacesAndNewlines)) }
                }
                states[item.id] = .succeeded
                log("\(item.name) verified: \(verification)")
            } catch {
                if cancelRequested {
                    states[item.id] = .paused("Stopped by user. Package-manager state may be partial; inspect before retrying.")
                    log("\(item.name): stop requested. Check Homebrew state before retrying; child build tools may take a moment to exit.")
                    break
                }
                states[item.id] = .failed(error.localizedDescription)
                log("\(item.name) failed: \(error.localizedDescription)")
            }
        }

        if cancelRequested { log("Queue cancelled. No further components will be started.") }
        else { log("Installation queue finished.") }
    }

    func refreshThermalState() { thermalState = HardwareChecker.thermalStateDescription }

    func log(_ message: String) {
        let line = "[\(Date.now.formatted(date: .omitted, time: .standard))] \(message)"
        logLines.append(line)
        if logLines.count > 400 { logLines.removeFirst(logLines.count - 400) }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JARVIS AI Workstation", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("installer.log")
        let data = (line + "\n").data(using: .utf8)!
        if FileManager.default.fileExists(atPath: file.path), let handle = try? FileHandle(forWritingTo: file) {
            try? handle.seekToEnd(); try? handle.write(contentsOf: data); try? handle.close()
        } else { try? data.write(to: file) }
    }
}

private final class SafeCommandRunner {
    private let lock = NSLock()
    private var activeProcess: Process?
    private var cancellationRequested = false

    func executableExists(_ path: String) -> Bool { FileManager.default.isExecutableFile(atPath: path) }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let process = activeProcess
        lock.unlock()
        if let process, process.isRunning { process.terminate() }
    }

    func resetCancellation() {
        lock.lock()
        cancellationRequested = false
        activeProcess = nil
        lock.unlock()
    }

    func run(_ executable: String, _ arguments: [String],
             onOutput: @escaping @Sendable (String) -> Void) async throws -> String {
        try await Task.detached(priority: .utility) { [self] in
            guard executable == "/opt/homebrew/bin/brew" else { throw RunnerError.disallowed }
            guard FileManager.default.isExecutableFile(atPath: executable) else { throw RunnerError.missing }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            lock.lock()
            activeProcess = process
            lock.unlock()

            let outputLock = NSLock()
            var captured = Data()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                outputLock.lock()
                captured.append(data)
                outputLock.unlock()
                if let text = String(data: data, encoding: .utf8), !text.isEmpty { onOutput(text) }
            }

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                lock.lock(); activeProcess = nil; lock.unlock()
                throw error
            }

            pipe.fileHandleForReading.readabilityHandler = nil
            let tail = pipe.fileHandleForReading.readDataToEndOfFile()
            outputLock.lock()
            if !tail.isEmpty { captured.append(tail) }
            let data = captured
            outputLock.unlock()

            lock.lock()
            let wasCancelled = cancellationRequested
            activeProcess = nil
            lock.unlock()

            if wasCancelled { throw RunnerError.cancelled }
            let output = String(data: data, encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else { throw RunnerError.failed(output) }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }.value
    }

    enum RunnerError: LocalizedError {
        case disallowed, missing, cancelled, failed(String)
        var errorDescription: String? {
            switch self {
            case .disallowed: return "Executable is not allowlisted."
            case .missing: return "Homebrew executable not found."
            case .cancelled: return "Installation was cancelled."
            case .failed(let output): return output.isEmpty ? "Installer returned a non-zero exit code." : output
            }
        }
    }
}
