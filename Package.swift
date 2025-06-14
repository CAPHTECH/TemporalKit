// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TemporalKit",
    platforms: [
        .macOS(.v10_15), // Example platform, adjust as needed
        .iOS(.v13),      // Example platform, adjust as needed
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TemporalKit",
            targets: ["TemporalKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TemporalKit",
            dependencies: []
        ),
        .testTarget(
            name: "TemporalKitTests",
            dependencies: [
                "TemporalKit",
            ]
        ),
        .executableTarget( // Add this new executable target
            name: "TemporalKitDemo",
            dependencies: ["TemporalKit"],
            path: "Sources/TemporalKitDemo",
            resources: [
                .copy("README.md")
            ]
        )
    ]
)
