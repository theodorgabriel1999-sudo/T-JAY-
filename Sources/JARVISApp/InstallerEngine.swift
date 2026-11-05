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
    @Published var cpuUsagePercent: Double? = nil
    @Published var cpuAssessment = "Measuring system load…"
    private var cpuSamples: [Double] = []

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

        currentStep = "Checking system load before installation"
        guard await performCPUPreflight() else {
            currentStep = "Waiting for safer system conditions"
            log("Preflight blocked installation. Close demanding apps, allow the Mac to cool, then retry.")
            return
        }

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
            if HardwareChecker.shouldDeferNextInstallStep || (averageCPUUsage ?? 0) >= 90 {
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
            let componentName = item.name
            let viewModel = self
            do {
                let result = try await runner.run(item.executable, item.arguments) { [weak viewModel] chunk in
                    Task { @MainActor [weak viewModel] in
                        guard let viewModel else { return }
                        viewModel.currentStep = "Installing \(componentName)"
                        viewModel.currentOutput = String((viewModel.currentOutput + chunk).suffix(5000))
                        viewModel.log(chunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                if !result.isEmpty { log(result) }
                if cancelRequested { break }
                currentStep = "Verifying \(item.name)"
                let verification = try await runner.run(item.verificationExecutable, item.verificationArguments) { [weak viewModel] chunk in
                    Task { @MainActor [weak viewModel] in
                        viewModel?.log(chunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
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

    var averageCPUUsage: Double? {
        guard !cpuSamples.isEmpty else { return cpuUsagePercent }
        return cpuSamples.reduce(0, +) / Double(cpuSamples.count)
    }

    func refreshThermalState() {
        thermalState = HardwareChecker.thermalStateDescription
        guard let sample = HardwareChecker.cpuTicks() else {
            cpuAssessment = "CPU load unavailable"
            return
        }
        if let previous = lastCPUTicks, let usage = HardwareChecker.cpuUsagePercent(from: previous, to: sample) {
            cpuUsagePercent = usage
            cpuSamples.append(usage)
            if cpuSamples.count > 6 { cpuSamples.removeFirst(cpuSamples.count - 6) }
            let average = averageCPUUsage ?? usage
            cpuAssessment = average >= 95 ? "Critical — new work blocked" :
                average >= 90 ? "Serious — pause before next step" :
                average >= 80 ? "High — reduced build concurrency" :
                average >= 60 ? "Elevated — monitoring" : "Normal"
        }
        lastCPUTicks = sample
    }

    private var lastCPUTicks: (total: UInt64, idle: UInt64)?

    private func performCPUPreflight() async -> Bool {
        guard let first = HardwareChecker.cpuTicks() else {
            cpuAssessment = "CPU load unavailable — cannot verify safe start"
            return false
        }
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        guard let second = HardwareChecker.cpuTicks(),
              let usage = HardwareChecker.cpuUsagePercent(from: first, to: second) else {
            cpuAssessment = "CPU load unavailable — cannot verify safe start"
            return false
        }
        cpuUsagePercent = usage
        cpuSamples = [usage]
        lastCPUTicks = second
        thermalState = HardwareChecker.thermalStateDescription
        if HardwareChecker.shouldDeferNextInstallStep || usage >= 90 {
            cpuAssessment = usage >= 95 ? "Critical — installation blocked" : "Serious — installation blocked"
            return false
        }
        cpuAssessment = usage >= 80 ? "High — cautious install profile" :
            usage >= 60 ? "Elevated — monitoring" : "Normal"
        return true
    }

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
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
            _ = try? handle.close()
        } else { try? data.write(to: file) }
    }
}

// Mutable state shared with the pipe callback is isolated behind synchronous lock methods.
private final class LockedOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func snapshot() -> Data {
        lock.lock()
        let copy = data
        lock.unlock()
        return copy
    }
}

private final class SafeCommandRunner: @unchecked Sendable {
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
            try runSynchronously(executable, arguments, onOutput: onOutput)
        }.value
    }

    private func runSynchronously(_ executable: String, _ arguments: [String],
                                  onOutput: @escaping @Sendable (String) -> Void) throws -> String {
        guard executable == "/opt/homebrew/bin/brew" else { throw RunnerError.disallowed }
        guard FileManager.default.isExecutableFile(atPath: executable) else { throw RunnerError.missing }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        // Conservative Homebrew build parallelism: do not consume every core.
        process.environment = ProcessInfo.processInfo.environment.merging(["HOMEBREW_MAKE_JOBS": "2"]) { _, new in new }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let captured = LockedOutput()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            captured.append(chunk)
            if let text = String(data: chunk, encoding: .utf8), !text.isEmpty {
                onOutput(text)
            }
        }

        // Launch while holding the lock so cancel() cannot slip between registration and launch.
        lock.lock()
        if cancellationRequested {
            lock.unlock()
            pipe.fileHandleForReading.readabilityHandler = nil
            throw RunnerError.cancelled
        }
        activeProcess = process
        do {
            try process.run()
        } catch {
            activeProcess = nil
            lock.unlock()
            pipe.fileHandleForReading.readabilityHandler = nil
            throw error
        }
        lock.unlock()

        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        let tail = pipe.fileHandleForReading.readDataToEndOfFile()
        if !tail.isEmpty { captured.append(tail) }

        lock.lock()
        let wasCancelled = cancellationRequested
        activeProcess = nil
        lock.unlock()

        if wasCancelled { throw RunnerError.cancelled }
        let output = String(data: captured.snapshot(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else { throw RunnerError.failed(output) }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
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
