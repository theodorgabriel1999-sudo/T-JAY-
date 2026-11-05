import Foundation
import Darwin

enum HardwareChecker {
    static func inspect() -> HardwareReport {
        let arch = Self.sysctlString("hw.machine") ?? "unknown"
        let chip = Self.sysctlString("machdep.cpu.brand_string") ?? arch
        let memory = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let version = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let free = max(0, (values?.volumeAvailableCapacityForImportantUsage ?? 0) / 1_073_741_824)
        var notes: [String] = []
        let supported = arch == "arm64" && v.majorVersion >= 14
        if arch != "arm64" { notes.append("Apple Silicon only: Intel Macs are not supported.") }
        if v.majorVersion < 14 { notes.append("macOS 14 Sonoma or later is required.") }
        if memory < 8 { notes.append("At least 8 GB RAM is recommended.") }
        if free < 20 { notes.append("At least 20 GB free disk space is recommended.") }
        return HardwareReport(chip: chip, architecture: arch, memoryGB: memory,
            macOS: version, freeDiskGB: Int(free), supported: supported, notes: notes)
    }

    static var thermalStateDescription: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "High thermal pressure"
        case .critical: return "Critical thermal pressure"
        @unknown default: return "Unknown"
        }
    }

    static var shouldDeferNextInstallStep: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    private static func sysctlString(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &value, &size, nil, 0) == 0 else { return nil }
        return String(cString: value)
    }
}
