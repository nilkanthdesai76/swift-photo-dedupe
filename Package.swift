// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftPhotoDedupe",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "PhotoHashKit",
            targets: ["PhotoHashKit"]
        ),
        .executable(
            name: "PhotoDedupeCLI",
            targets: ["PhotoDedupeCLI"]
        ),
        .executable(
            name: "PhotoDedupeApp",
            targets: ["PhotoDedupeApp"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PhotoHashKit",
            dependencies: [],
            path: "Sources/PhotoHashKit"
        ),
        .executableTarget(
            name: "PhotoDedupeCLI",
            dependencies: ["PhotoHashKit"],
            path: "Sources/PhotoDedupeCLI"
        ),
        .executableTarget(
            name: "PhotoDedupeApp",
            dependencies: ["PhotoHashKit"],
            path: "Sources/PhotoDedupeApp"
        ),
        .testTarget(
            name: "PhotoHashKitTests",
            dependencies: ["PhotoHashKit"],
            path: "Tests/PhotoHashKitTests"
        ),
    ]
)
