// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "NotchEventBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "NotchEventBar",
            targets: ["NotchEventBar"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "NotchEventBar",
            path: "Sources",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NotchEventBarTests",
            dependencies: ["NotchEventBar"],
            path: "Tests/NotchEventBarTests"
        ),
    ]
)
