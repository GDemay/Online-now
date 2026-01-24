# OnlineNow - Connectivity Intelligence SDK

A production-ready Swift SDK for real-time connectivity monitoring, captive portal detection, and network resiliency. Built for high-stakes applications like Fintech, E-commerce, and SaaS platforms.

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS 15.0+](https://img.shields.io/badge/iOS-15.0+-blue.svg)](https://developer.apple.com/ios/)
[![macOS 12.0+](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://developer.apple.com/macos/)
[![watchOS 8.0+](https://img.shields.io/badge/watchOS-8.0+-blue.svg)](https://developer.apple.com/watchos/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 🚀 Why OnlineNow?

Most connectivity libraries only check if a network interface is up. OnlineNow goes further by detecting the **"Gray Zone"**—scenarios where the OS reports WiFi connected, but you're behind a captive portal (hotel WiFi) or on a degraded link that can't pass data.

### Commercial Benefits

- **Reduced Churn**: Prevent users from clicking "Pay" when the connection is unstable
- **Improved UX**: Drop-in, Netflix-style connectivity banners that require zero design work
- **Operational Safety**: Automatic retry with idempotency hooks to prevent duplicate requests during reconnection

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔍 **True Reachability** | Validates actual internet connectivity, not just interface status |
| 🏨 **Captive Portal Detection** | Detects hotel WiFi, airport portals, and corporate firewalls |
| 📊 **Network Metadata** | Exposes `isExpensive`, `isConstrained`, and VPN/Proxy detection |
| 🔄 **Automatic Retry** | `NetworkRetry` wrapper with exponential backoff and connectivity awareness |
| 🧪 **Mocking Support** | `MockNetworkMonitor` for SwiftUI Previews and Unit Tests |
| 📱 **Drop-in UI** | Connectivity banner ViewModifier with haptic feedback |
| 🔒 **App Store Ready** | Includes `PrivacyInfo.xcprivacy` for 2024/2025 compliance |
| 🌐 **Multi-Platform** | Supports iOS, macOS, watchOS, and tvOS |

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/GDemay/Online-now.git", from: "2.0.0")
]
```

Or in Xcode: **File → Add Packages...** and enter the repository URL.

## 🎯 Quick Start

### 1. Add Connectivity Banner (Zero-Config)

```swift
import SwiftUI
import OnlineNow

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .connectivityBanner()  // Netflix-style banner
        }
    }
}
```

### 2. Use Resilient Network Requests

```swift
import OnlineNow

let retry = NetworkRetry()

let result = await retry.execute(
    description: "Process payment",
    configuration: .critical  // 5 retries, 5-minute timeout
) {
    try await paymentAPI.processTransaction(amount: 99.99)
}

switch result {
case .success(let receipt):
    showSuccessScreen(receipt)
case .failure(let error):
    showError(error.localizedDescription)
}
```

### 3. Check Connectivity Status

```swift
import OnlineNow

let reachability = ReachabilityService()
let (status, captivePortal) = await reachability.checkConnectivity()

if captivePortal.isCaptivePortal {
    // Show "Login to WiFi" prompt
    if let portalURL = captivePortal.portalURL {
        openSafari(portalURL)
    }
} else if status.isReachable {
    // Proceed with network operations
} else {
    // Show offline state
}
```

### 4. Monitor Real-Time Status

```swift
import OnlineNow
import Combine

class NetworkStatusManager: ObservableObject {
    private let monitor = NetworkMonitor()
    private var cancellables = Set<AnyCancellable>()

    init() {
        monitor.start()

        monitor.$isConnected
            .combineLatest(monitor.$connectionType)
            .sink { [weak self] isConnected, type in
                print("Status: \(isConnected ? "Online" : "Offline") via \(type.rawValue)")
            }
            .store(in: &cancellables)
    }
}
```

## 🧪 Testing & Previews

Use `MockNetworkMonitor` to simulate network conditions:

```swift
import SwiftUI
import OnlineNow

struct PaymentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaymentView()
                .mockNetworkScenario(.connected)
                .previewDisplayName("Connected")

            PaymentView()
                .mockNetworkScenario(.captivePortal)
                .previewDisplayName("Captive Portal")

            PaymentView()
                .mockNetworkScenario(.disconnected)
                .previewDisplayName("Offline")
        }
    }
}
```

Available scenarios:
- `.connected` - Full connectivity (WiFi)
- `.disconnected` - No network
- `.captivePortal` - Behind login portal
- `.slowConnection` - High latency, low speed
- `.unstable` - Intermittent drops
- `.cellularExpensive` - Metered connection
- `.vpnActive` - VPN tunnel active
- `.lowDataMode` - Constrained bandwidth

## 📖 API Reference

### Core Types

| Type | Description |
|------|-------------|
| `ConnectivityStatus` | `.connected`, `.disconnected`, `.captivePortal`, `.localOnly`, `.checking` |
| `NetworkMetadata` | Connection details including `isExpensive`, `isConstrained`, `isUsingTunnel` |
| `SignalQuality` | `.excellent`, `.good`, `.fair`, `.poor`, `.unknown` |

### Services

| Service | Description |
|---------|-------------|
| `NetworkMonitor` | Real-time NWPathMonitor wrapper with VPN detection |
| `ReachabilityService` | True reachability + captive portal detection |
| `NetworkRetry` | Resilient operation wrapper with exponential backoff |

### UI Components

| Component | Description |
|-----------|-------------|
| `.connectivityBanner()` | Drop-in status bar overlay |
| `.netflixConnectivityBanner()` | Netflix-style bottom banner |
| `.minimalConnectivityBanner()` | Shows only disconnected state |

### Configuration

```swift
// Retry configurations
NetworkRetryConfiguration.quick      // 2 retries, 30s timeout
NetworkRetryConfiguration.critical   // 5 retries, 5min timeout
NetworkRetryConfiguration.background // 10 retries, no timeout

// Banner configurations
ConnectivityBannerConfiguration.default     // Top, show problems
ConnectivityBannerConfiguration.netflixStyle // Bottom, auto-dismiss
ConnectivityBannerConfiguration.verbose      // Always visible
```

## 🔐 Privacy & Compliance

OnlineNow includes a `PrivacyInfo.xcprivacy` manifest declaring:
- **No user data collection** - Only monitors device connectivity
- **No tracking** - No tracking domains or fingerprinting
- **Required Reason APIs** - Properly declared for App Store review

## 📋 Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS | 15.0+ |
| macOS | 12.0+ |
| watchOS | 8.0+ |
| tvOS | 15.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.
2. Toggle airplane mode on/off
3. Switch between WiFi and cellular data
4. Observe the real-time status updates

## License

This project is available for use under standard open source practices.

## Author

GDemay
