// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Music",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Music", targets: ["Music"])
    ],
    targets: [
        .executableTarget(
            name: "Music",
            path: "Sources"
        )
    ]
)
