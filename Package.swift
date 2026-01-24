// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OnlineNow",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "OnlineNow",
            targets: ["OnlineNow"]),
    ],
    targets: [
        .target(
            name: "OnlineNow",
            dependencies: [],
            path: "Sources/OnlineNow"),
    ]
)
