// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "JARVISAIWorkstation",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "JARVISAIWorkstation", targets: ["JARVISApp"])],
    targets: [.executableTarget(
        name: "JARVISApp",
        path: "Sources/JARVISApp",
        resources: [.copy("../../Resources/components.json")]
    )]
)
