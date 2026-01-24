# Online Now - Project Architecture

## Project Structure

```
Online-now/
├── App/                          # iOS App Entry Point
│   ├── OnlineNowApp.swift       # Main app file with @main attribute
│   └── Info.plist               # iOS app configuration
├── Sources/OnlineNow/            # Core Library
│   ├── NetworkMonitor.swift     # Network connectivity monitor
│   └── ConnectivityStatusView.swift  # SwiftUI view component
├── Examples/                     # Usage Examples
│   └── UsageExamples.swift      # SwiftUI and UIKit examples
├── Package.swift                 # Swift Package Manager config
├── project.yml                   # XcodeGen config (optional)
└── README.md                     # Documentation
```

## Architecture Overview

### NetworkMonitor Class
- Uses Apple's `Network` framework (NWPathMonitor)
- Observes network path changes in real-time
- Publishes `isConnected` and `connectionType` properties
- Thread-safe with proper dispatch queue management

### ConnectivityStatusView
- SwiftUI view that observes NetworkMonitor
- Automatically starts/stops monitoring with lifecycle
- Displays:
  - Background color (green for online, red for offline)
  - WiFi icon (wifi or wifi.slash)
  - Status text ("Online" or "Offline")
  - Connection type ("via WiFi", "via Cellular", etc.)

### OnlineNowApp
- Main entry point using SwiftUI App protocol
- Creates a WindowGroup with ConnectivityStatusView

## How It Works

1. **App Launch**: OnlineNowApp initializes and displays ConnectivityStatusView
2. **View Appears**: NetworkMonitor.start() is called, beginning network monitoring
3. **Network Changes**: NWPathMonitor detects connectivity changes
4. **State Updates**: @Published properties update on main thread
5. **UI Updates**: SwiftUI automatically re-renders the view
6. **View Disappears**: NetworkMonitor.stop() is called, stopping monitoring

## Usage Patterns

### Pattern 1: Direct View Usage
```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ConnectivityStatusView()
        }
    }
}
```

### Pattern 2: Custom Implementation
```swift
struct MyView: View {
    @StateObject private var networkMonitor = NetworkMonitor()
    
    var body: some View {
        Text(networkMonitor.isConnected ? "Online" : "Offline")
            .onAppear { networkMonitor.start() }
            .onDisappear { networkMonitor.stop() }
    }
}
```

### Pattern 3: UIKit Integration
```swift
class MyViewController: UIViewController {
    private let networkMonitor = NetworkMonitor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        networkMonitor.$isConnected
            .sink { isConnected in
                // Update UI
            }
            .store(in: &cancellables)
        networkMonitor.start()
    }
}
```

## Key Features

1. **Real-time Monitoring**: Instant updates when connectivity changes
2. **Connection Type Detection**: Identifies WiFi, Cellular, Ethernet
3. **Combine Integration**: Uses @Published for reactive updates
4. **Lifecycle Management**: Proper start/stop in view lifecycle
5. **Thread Safety**: All UI updates on main thread
6. **Memory Safe**: Uses weak self to prevent retain cycles

## Testing

To test the app:
1. Open in Xcode (requires macOS with Xcode installed)
2. Run on iOS Simulator or physical device
3. Toggle network connectivity (Airplane mode, WiFi on/off)
4. Observe real-time status updates

## Dependencies

- iOS 15.0+ (for SwiftUI features)
- Network framework (system framework, no external dependencies)
- Combine framework (system framework, no external dependencies)
