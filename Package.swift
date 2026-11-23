// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "BetterClean",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic with no AppKit/system dependencies, so it can be unit tested.
        .target(name: "CleaningCore"),
        // The menu bar app: event tap, overlay, Touch ID, system guards.
        .executableTarget(
            name: "BetterClean",
            dependencies: ["CleaningCore"]
        ),
        .testTarget(
            name: "CleaningCoreTests",
            dependencies: ["CleaningCore"]
        ),
    ]
)
