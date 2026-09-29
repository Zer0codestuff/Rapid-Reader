// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RapidReader",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "RapidReaderCore", targets: ["RapidReaderCore"]),
        .executable(name: "RapidReader", targets: ["RapidReader"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .target(
            name: "RapidReaderCore",
            dependencies: ["ZIPFoundation", "SwiftSoup"],
            path: "Sources/RapidReaderCore"
        ),
        .executableTarget(
            name: "RapidReader",
            dependencies: ["RapidReaderCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/RapidReader",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                // Sparkle.framework is embedded in Contents/Frameworks by script/build_and_run.sh.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "RapidReaderCoreTests",
            dependencies: ["RapidReaderCore", "ZIPFoundation"],
            path: "Tests/RapidReaderCoreTests"
        )
    ]
)
