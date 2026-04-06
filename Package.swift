// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Cronly",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "cronly", targets: ["CronlyCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "CronlyKit",
            path: "Sources/CronlyKit"
        ),
        .executableTarget(
            name: "CronlyCLI",
            dependencies: [
                "CronlyKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/CronlyCLI"
        ),
        .executableTarget(
            name: "CronlyApp",
            dependencies: ["CronlyKit"],
            path: "Sources/CronlyApp"
        ),
    ]
)
