//
//  OnlineNow.swift
//  OnlineNow - Connectivity Intelligence SDK
//
//  A production-ready SDK for real-time connectivity monitoring,
//  captive portal detection, and network resiliency.
//

import Foundation

/// OnlineNow SDK Version
public let OnlineNowVersion = "2.0.0"

/// OnlineNow SDK Build Information
public struct OnlineNowInfo {
    /// SDK Version string
    public static let version = OnlineNowVersion

    /// Minimum supported iOS version
    public static let minimumIOSVersion = "15.0"

    /// Minimum supported macOS version
    public static let minimumMacOSVersion = "12.0"

    /// Minimum supported watchOS version
    public static let minimumWatchOSVersion = "8.0"

    /// SDK capabilities
    public static let capabilities: [String] = [
        "Real-time connectivity monitoring",
        "Captive portal detection",
        "VPN/Proxy detection",
        "Network quality assessment",
        "Automatic retry with backoff",
        "Drop-in UI components",
        "Haptic feedback",
        "SwiftUI & Combine support",
        "Multi-platform support"
    ]

    private init() {}
}

// MARK: - Quick Start

/*
 Quick Start Guide
 =================

 1. Add the package to your project:

    .package(url: "https://github.com/GDemay/Online-now.git", from: "2.0.0")

 2. Import the library:

    import OnlineNow

 3. Add connectivity banner to your app (SwiftUI):

    @main
    struct MyApp: App {
        var body: some Scene {
            WindowGroup {
                ContentView()
                    .connectivityBanner()  // Netflix-style banner
            }
        }
    }

 4. Use NetworkRetry for resilient network operations:

    let retry = NetworkRetry()
    let result = await retry.execute(
        description: "Fetch user profile",
        configuration: .critical
    ) {
        try await api.fetchUserProfile()
    }

    switch result {
    case .success(let profile):
        // Handle success
    case .failure(let error):
        // Handle failure after retries exhausted
    }

 5. Use MockNetworkMonitor for testing:

    struct MyView_Previews: PreviewProvider {
        static var previews: some View {
            MyView()
                .mockNetworkScenario(.captivePortal)
        }
    }

 For more information, see the SDK documentation.
 */
