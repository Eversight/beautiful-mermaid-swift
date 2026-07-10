// swift-tools-version: 6.1
import PackageDescription

// All targets are pinned to the Swift 5 language mode for now: the vendored ELK
// port (56 KLOC of mechanically translated Java) predates strict concurrency.
// Targets migrate to the Swift 6 language mode individually as they are audited.
let v5: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "BeautifulMermaidSwift",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .macCatalyst(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "BeautifulMermaid", targets: ["BeautifulMermaid"]),
        .executable(name: "MermaidPlayground", targets: ["MermaidPlayground"])
    ],
    targets: [
        // The layout engine. Originally ported from the Eclipse Layout Kernel
        // (Java); has since diverged — this Swift source is authoritative.
        // The LICENSE file (EPL-2.0) covers the derived portions.
        .target(
            name: "LayoutKernel",
            path: "Sources/LayoutKernel",
            exclude: ["LICENSE"],
            swiftSettings: v5
        ),
        .target(
            name: "BeautifulMermaid",
            dependencies: ["LayoutKernel"],
            path: "Sources/BeautifulMermaidSwift",
            swiftSettings: v5
        ),
        .executableTarget(
            name: "bench",
            dependencies: ["BeautifulMermaid"],
            path: "Benchmarks",
            swiftSettings: v5
        ),
        .executableTarget(
            name: "MermaidPlayground",
            dependencies: ["BeautifulMermaid"],
            path: "Examples/MermaidPlayground",
            exclude: [
                "Info.plist",
                "Scripts"
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: v5
        ),
        .testTarget(
            name: "BeautifulMermaidSwiftTests",
            dependencies: ["BeautifulMermaid"],
            // Golden fixtures are read via #filePath, not Bundle resources.
            exclude: ["Golden"],
            swiftSettings: v5
        ),
        .testTarget(
            name: "LayoutKernelTests",
            dependencies: ["LayoutKernel"],
            swiftSettings: v5
        )
    ]
)
