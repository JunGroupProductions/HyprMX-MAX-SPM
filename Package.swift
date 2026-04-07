// swift-tools-version:5.3
// HyprMX-Max adapter for AppLovin MAX mediation.
// Version: 6.4.6.0
import PackageDescription

let package = Package(
    name: "HyprMX_Max",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "HyprMX_Max",
            targets: ["HyprMX_Max"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/JunGroupProductions/HyprMX-SDK-SPM.git", .exact("6.4.6")),
        .package(url: "https://github.com/AppLovin/AppLovin-MAX-Swift-Package.git", "12.4.0"..<"14.0.0"),
    ],
    targets: [
        .target(
            name: "HyprMX_Max",
            dependencies: [
                .product(name: "HyprMX", package: "HyprMX-SDK-SPM"),
                .product(name: "AppLovinSDK", package: "AppLovin-MAX-Swift-Package"),
            ],
            path: "HyprMX-Max",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath("."),
            ]
        ),
    ]
)
