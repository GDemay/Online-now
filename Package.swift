// swift-tools-version:5.9
import PackageDescription

// The native app/SDK uses Apple's Network, Combine, SwiftUI and StoreKit frameworks.
// Linux verifies only the Foundation transaction ledger, never a substitute iOS build.
let coreTarget = Target.target(
    name: "OnlineNowCore",
    path: "Sources/OnlineNow/Services",
    exclude: [
        "DiagnosticService.swift", "HistoryManager.swift", "LatencyMeasurementService.swift",
        "NetworkRetry.swift", "ReachabilityService.swift", "SpeedTestService.swift", "TippingManager.swift"
    ],
    sources: ["TipLedger.swift"]
)
let coreTests = Target.testTarget(
    name: "OnlineNowCoreTests", dependencies: ["OnlineNowCore"], path: "Tests/OnlineNowCoreTests"
)
#if os(Linux)
let package = Package(name: "OnlineNow", targets: [coreTarget, coreTests])
#else
let package = Package(
    name: "OnlineNow",
    platforms: [.iOS(.v15), .macOS(.v12), .watchOS(.v8), .tvOS(.v15)],
    products: [.library(name: "OnlineNow", targets: ["OnlineNow"])],
    targets: [
        .target(
            name: "OnlineNow", dependencies: [], path: "Sources/OnlineNow",
            exclude: [
                "ConnectivityStatusView.swift", "Views/HistoryListView.swift", "Views/StatDetailView.swift",
                "Views/LogoView.swift", "ViewModels/ConnectivityViewModel.swift",
                "Services/HistoryManager.swift", "Models/ConnectivityCheck.swift"
            ],
            resources: [.process("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(name: "OnlineNowTests", dependencies: ["OnlineNow"], path: "Tests/OnlineNowTests"),
        coreTarget, coreTests
    ]
)
#endif
