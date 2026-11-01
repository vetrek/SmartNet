// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SmartNet",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SmartNet",
            targets: ["SmartNet"]),
    ],
    targets: [
        .target(
            name: "SmartNet",
            path: "Source",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "SmartNetIntegrationTests",
            dependencies: ["SmartNet"],
            path: "Tests/IntegrationTests"
        ),
        .testTarget(
            name: "SmartNetUnitTests",
            dependencies: ["SmartNet"],
            path: "Tests/UnitTests"
        ),
    ]
)
