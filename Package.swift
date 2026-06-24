// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeReadNotesManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WeReadNotesManager",
            path: "Sources/WeReadNotesManager"
        ),
        .testTarget(
            name: "WeReadNotesManagerTests",
            dependencies: ["WeReadNotesManager"],
            path: "Tests/WeReadNotesManagerTests"
        )
    ]
)
