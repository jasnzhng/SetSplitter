// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SetSplitterCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SetSplitterCore", targets: ["SetSplitterCore"]),
    ],
    targets: [
        .target(
            name: "SetSplitterCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "SetSplitterCoreTests",
            dependencies: ["SetSplitterCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
