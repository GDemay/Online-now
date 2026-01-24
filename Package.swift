// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OnlineNow",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
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
            path: "Sources/OnlineNow",
            exclude: [
                // Exclude iOS 17+ SwiftData/Charts UI files from library builds
                // These are only for the demo app (OnlineNow.xcodeproj)
                "ConnectivityStatusView.swift",
                "Views/HistoryListView.swift",
                "Views/StatDetailView.swift",
                "Views/LogoView.swift",
                "ViewModels/ConnectivityViewModel.swift",
                "Services/HistoryManager.swift",
                "Models/ConnectivityCheck.swift"
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "OnlineNowTests",
            dependencies: ["OnlineNow"],
            path: "Tests/OnlineNowTests"
        )
    ]
)
