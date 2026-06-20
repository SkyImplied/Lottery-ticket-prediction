// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CaipiaoPredictor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CaipiaoPredictor", targets: ["CaipiaoPredictor"])
    ],
    targets: [
        .executableTarget(
            name: "CaipiaoPredictor",
            resources: [
                .copy("Resources/bundled_draws.json"),
                .copy("Resources/AppLogo.png"),
                .copy("Resources/AppIcon.icns")
            ]
        )
    ]
)
