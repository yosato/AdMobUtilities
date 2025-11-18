// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AdMobUtilities",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AdMobUtilities", targets: ["AdMobUtilities"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AdMobUtilities",
            dependencies: []
        )
    ]
)
