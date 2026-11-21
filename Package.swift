// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitAccount",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "git-account", targets: ["GitAccountCLI"]),
        .library(name: "GitAccountCore", targets: ["GitAccountCore"])
    ],
    targets: [
        .target(name: "GitAccountCore"),
        .executableTarget(name: "GitAccountCLI", dependencies: ["GitAccountCore"]),
        .testTarget(name: "GitAccountCoreTests", dependencies: ["GitAccountCore"])
    ]
)
