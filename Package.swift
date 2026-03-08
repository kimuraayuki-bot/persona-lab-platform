// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PersonaLab",
    defaultLocalization: "ja",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PersonaLabCore", targets: ["PersonaLabCore"]),
        .executable(name: "PersonaLabApp", targets: ["PersonaLabApp"])
    ],
    targets: [
        .target(
            name: "PersonaLabCore",
            path: "Sources/PersonaLabCore"
        ),
        .executableTarget(
            name: "PersonaLabApp",
            dependencies: ["PersonaLabCore"],
            path: "Sources/PersonaLabApp"
        ),
        .testTarget(
            name: "PersonaLabCoreTests",
            dependencies: ["PersonaLabCore"],
            path: "Tests/PersonaLabCoreTests"
        )
    ]
)
