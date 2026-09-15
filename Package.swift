// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Brewwery",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Brewwery", targets: ["Brewwery"]),
        .library(name: "BrewweryCore", targets: ["BrewweryCore"])
    ],
    dependencies: [
        // Application updates only. Homebrew package updates never go through Sparkle.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .target(
            name: "BrewweryCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "Brewwery",
            dependencies: [
                "BrewweryCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)],
            // The packaged app embeds Sparkle.framework in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        // A scriptable `brew` double shared by the core and app test suites.
        .target(
            name: "BrewweryTestSupport",
            dependencies: ["BrewweryCore"],
            path: "Tests/BrewweryTestSupport",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Feature models, rendering, keyboard behaviour and accessibility of the app itself.
        .testTarget(
            name: "BrewweryAppTests",
            dependencies: ["Brewwery", "BrewweryCore", "BrewweryTestSupport"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        // Exercises the real Homebrew on this Mac. Every test skips unless BREWWERY_LIVE=1, so a
        // plain `swift test` never installs, starts or upgrades anything.
        .testTarget(
            name: "BrewweryLiveTests",
            dependencies: ["BrewweryCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "BrewweryCoreTests",
            dependencies: ["BrewweryCore", "BrewweryTestSupport"],
            resources: [.process("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
