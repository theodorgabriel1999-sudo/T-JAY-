import Foundation

struct AIProjectCatalog: Decodable {
    let schemaVersion: Int
    let catalogueVersion: String
    let status: String?
    let projects: [AIProject]
}

struct AIProject: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let capabilities: [String]
    let summary: String
    let source: URL
    let website: URL?
    let license: String
    let licenseStatus: String?
    let execution: String
    let macOS: AIProjectMacOS?
    let resourceClass: String?
    let dependencies: [String]
    let optionalDependencies: [String]?
    let integrationNotes: String?
    let installStatus: String?
    let launch: AIProjectLaunch?
    let reviewRequired: Bool?
    let upstreamVersion: String?
    let pinnedCommit: String?
    let verifiedAt: String?

    var isKnownInstalled: Bool {
        installStatus == "already-installed-on-user-machine"
    }

    var localSourceDirectory: URL? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support
            .appendingPathComponent("JARVIS AI Workstation/Projects", isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) ? directory : nil
    }

    var isSourceCheckedOut: Bool { localSourceDirectory != nil }
}

struct AIProjectMacOS: Decodable, Hashable {
    let appleSilicon: String?
    let minimum: String?
    let verification: String?
}

struct AIProjectLaunch: Decodable, Hashable {
    let kind: String?
    let url: URL?
    let discovery: String?
    let targetProjectID: String?
}
