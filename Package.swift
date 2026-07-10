// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SonixMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SonixMac",
            targets: ["SonixMac"]),
    ],
    targets: [
        .executableTarget(
            name: "SonixMac",
            path: "Sources/SonixMac",
            resources: []
        )
    ]
)
