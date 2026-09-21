// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpacePeek",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SpacePeek",
            path: "Sources/SpacePeek"
        ),
        .testTarget(
            name: "SpacePeekTests",
            dependencies: ["SpacePeek"],
            path: "Tests/SpacePeekTests"
        )
    ]
)
