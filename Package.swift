// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeployBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DeployBar", targets: ["DeployBar"])
    ],
    targets: [
        .executableTarget(
            name: "DeployBar",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)

