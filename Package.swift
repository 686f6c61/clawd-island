// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeIsland",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ClaudeIsland", targets: ["ClaudeIsland"]),
        .executable(name: "ClaudeIslandHook", targets: ["ClaudeIslandHook"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.4"),
    ],
    targets: [
        .target(name: "ClaudeIslandCore"),
        .executableTarget(
            name: "ClaudeIsland",
            dependencies: [
                "ClaudeIslandCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                ]),
            ]
        ),
        .executableTarget(
            name: "ClaudeIslandHook",
            dependencies: ["ClaudeIslandCore"]
        ),
        .testTarget(
            name: "ClaudeIslandCoreTests",
            dependencies: ["ClaudeIslandCore"]
        ),
        .testTarget(
            name: "ClaudeIslandTests",
            dependencies: ["ClaudeIsland"]
        ),
    ]
)
