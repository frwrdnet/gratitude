// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Gratitude",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Gratitude", targets: ["Gratitude"]),
    ],
    targets: [
        .target(
            name: "Gratitude",
            resources: [
                // .copy("Resources/Gratitude.storekit"), // optional local test config
            ]
        ),
    ]
)
