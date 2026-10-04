// swift-tools-version: 6.0
import PackageDescription

// Phase 0 feasibility spike. Throwaway.
// Language mode 5 here on purpose: the spike proves the AUDIO + METADATA pipeline,
// not strict-concurrency ergonomics. The real Packages/SetSplitterCore is Swift 6 mode.
let package = Package(
    name: "SplitSpike",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "split-spike",
            path: "Sources/split-spike",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
