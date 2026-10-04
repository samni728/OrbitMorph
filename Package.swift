// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OrbitMorph",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OrbitMorphCore", targets: ["OrbitMorphCore"]),
        .executable(name: "OrbitMorph", targets: ["OrbitMorphApp"])
    ],
    targets: [
        .target(name: "OrbitMorphCore"),
        .executableTarget(name: "OrbitMorphApp", dependencies: ["OrbitMorphCore"]),
        .testTarget(name: "OrbitMorphCoreTests", dependencies: ["OrbitMorphCore"]),
        .testTarget(name: "OrbitMorphAppTests", dependencies: ["OrbitMorphApp", "OrbitMorphCore"])
    ]
)
