# Quick Start Guide - Online Now

This guide will help you get started with the Online Now iOS app.

## Prerequisites

- macOS with Xcode 13.0 or later installed
- iOS device or iOS Simulator
- Basic knowledge of Swift and iOS development

## Option 1: Run as Standalone App

### Step 1: Clone the Repository
```bash
git clone https://github.com/GDemay/Online-now.git
cd Online-now
```

### Step 2: Generate Xcode Project (Optional)
If you have XcodeGen installed:
```bash
xcodegen generate
```

Or use Swift Package Manager directly:
```bash
open Package.swift
```

### Step 3: Build and Run
1. Open the project in Xcode
2. Select a target device or simulator
3. Press Cmd+R to build and run

### Step 4: Test Connectivity
- The app will show "Online" with a green background when connected
- Toggle Airplane mode to see the status change to "Offline" with red background
- The app updates in real-time as connectivity changes

## Option 2: Add to Your iOS Project

### Using Swift Package Manager

1. In Xcode, go to File → Add Packages...
2. Enter the repository URL: `https://github.com/GDemay/Online-now.git`
3. Select the version and click "Add Package"

### Using Package.swift

Add to your `Package.swift` dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/GDemay/Online-now.git", from: "1.0.0")
]
```

Then add to your target:
```swift
.target(
    name: "YourApp",
    dependencies: ["OnlineNow"]
)
```

### Basic Usage in Your App

```swift
import SwiftUI
import OnlineNow

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ConnectivityStatusView()
        }
    }
}
```

## Understanding the UI

### When Online (Connected)
- **Background**: Light green
- **Icon**: WiFi symbol
- **Text**: "Online" in green
- **Connection Type**: Shows "via WiFi", "via Cellular", or "via Ethernet"

### When Offline (Disconnected)
- **Background**: Light red
- **Icon**: WiFi symbol with slash
- **Text**: "Offline" in red
- **Connection Type**: Hidden

## Advanced Usage

### Custom Implementation

Create your own view using the NetworkMonitor:

```swift
import SwiftUI
import OnlineNow

struct MyConnectivityView: View {
    @StateObject private var monitor = NetworkMonitor()
    
    var body: some View {
        VStack {
            if monitor.isConnected {
                Text("✓ Connected")
            } else {
                Text("✗ Disconnected")
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}
```

### UIKit Integration

```swift
import UIKit
import OnlineNow
import Combine

class ViewController: UIViewController {
    private let monitor = NetworkMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        monitor.$isConnected
            .sink { [weak self] isConnected in
                self?.updateUI(isConnected)
            }
            .store(in: &cancellables)
        
        monitor.start()
    }
    
    private func updateUI(_ isConnected: Bool) {
        // Update your UI based on connectivity
        title = isConnected ? "Online" : "Offline"
    }
    
    deinit {
        monitor.stop()
    }
}
```

## Troubleshooting

### Build Errors
- Ensure you're using Xcode 13.0 or later
- Verify iOS deployment target is set to 15.0 or later
- Clean build folder (Cmd+Shift+K) and rebuild

### App Not Detecting Connectivity Changes
- Ensure you called `monitor.start()` before observing changes
- Verify you're running on a physical device or simulator with network access
- Check that the app has appropriate network permissions

### UI Not Updating
- Make sure `NetworkMonitor` is marked as `@StateObject` or `@ObservedObject` in SwiftUI
- Verify you're using Combine's `sink` properly in UIKit
- Ensure you're not blocking the main thread

## Next Steps

- Check out `Examples/UsageExamples.swift` for more implementation patterns
- Read `ARCHITECTURE.md` to understand how the app works
- Customize the UI by creating your own views using `NetworkMonitor`

## Need Help?

- Review the full documentation in `README.md`
- Check the architecture documentation in `ARCHITECTURE.md`
- Look at usage examples in `Examples/UsageExamples.swift`
