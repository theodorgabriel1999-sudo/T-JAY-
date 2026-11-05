import Foundation
struct ComponentManifest: Decodable {
    let schemaVersion: Int
    let productVersion: String
    let components: [Component]
}
struct Component: Decodable, Identifiable, Hashable {
    let id, name, summary, category: String
    let recommended, requiresHomebrew: Bool
    let minimumMacOS, executable: String
    let arguments: [String]
    let verificationExecutable: String
    let verificationArguments: [String]
    let license: String
    let sourceURL: URL
}
enum InstallState: Equatable {
    case idle, checking, installing, succeeded, failed(String)
}
struct HardwareReport {
    let chip, architecture: String
    let memoryGB: Int
    let macOS: String
    let freeDiskGB: Int
    let supported: Bool
    let notes: [String]
}
