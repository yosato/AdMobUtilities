// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AdMobUtilities",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AdMobUtilities", targets: ["AdMobUtilities"])
    ],
    dependencies: [        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "13.6.0")
],
    targets: [
        .target(
            name: "AdMobUtilities",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads")

            ]
        )
    ]
)
