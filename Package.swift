// swift-tools-version: 6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "Murmur",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MurmurKit", swiftSettings: swiftSettings),
        .executableTarget(name: "Murmur", dependencies: ["MurmurKit"], swiftSettings: swiftSettings),
        .testTarget(name: "MurmurKitTests", dependencies: ["MurmurKit"], swiftSettings: swiftSettings),
    ]
)
