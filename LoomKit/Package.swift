// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LoomKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "LoomKit", targets: ["LoomKit"])
    ],
    targets: [
        .target(
            name: "LoomKit",
            path: "Sources/LoomKit",
            resources: [
                .copy("Config/Resources/default-categories.json")
            ]
        ),
        .testTarget(
            name: "LoomKitTests",
            dependencies: ["LoomKit"],
            path: "Tests/LoomKitTests"
        )
    ]
)
