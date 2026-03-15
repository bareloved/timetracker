// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimeTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TimeTracker",
            path: "TimeTracker",
            resources: [
                .copy("Resources/default-categories.json")
            ]
        ),
        .testTarget(
            name: "TimeTrackerTests",
            dependencies: ["TimeTracker"],
            path: "TimeTrackerTests"
        )
    ]
)
