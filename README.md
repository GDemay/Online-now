# Online Now

**Internet Status & Speed History**

Online Now is a lightweight iOS app that tells you, instantly and reliably, whether you are connected to the internet — and how good that connection actually is.

## Features

- **Instant Internet Status**: Clearly indicates whether the device is currently online with real internet reachability checks
- **Connection Type Detection**: Distinguishes between Wi-Fi, Cellular, and No Connection
- **Reliable Speed Estimation**: Measures effective download speed with minimal data usage
- **Automatic History Tracking**: Every check is automatically saved locally with timestamp and connection details
- **Recent Activity Overview**: Displays last check result and time since last measurement
- **Private by Design**: All data stored only on your device - no accounts, tracking, or analytics
- **Simple, Focused Interface**: Single, distraction-free screen with clear states
- **Battery & Data Friendly**: No background activity, manual refresh only
- **Accessible**: Full support for Dynamic Type and VoiceOver

## Requirements

- iOS 15.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Building the App

1. Clone this repository:
   ```bash
   git clone https://github.com/GDemay/Online-now.git
   cd Online-now
   ```

2. Open the project in Xcode:
   ```bash
   open OnlineNow.xcodeproj
   ```

3. Select your target device or simulator

4. Build and run (⌘R)

## Project Structure

```
OnlineNow/
├── OnlineNowApp.swift          # App entry point
├── Models/
│   ├── ConnectionStatus.swift  # Connection type and state enums
│   └── CheckResult.swift       # Data model for check results
├── Services/
│   ├── NetworkMonitor.swift    # Network reachability monitoring
│   ├── SpeedTestService.swift  # Internet speed testing
│   └── HistoryManager.swift    # Local data persistence
├── Views/
│   ├── ContentView.swift       # Main app interface
│   └── HistoryView.swift       # History list display
├── Assets.xcassets/            # App icons and assets
└── Info.plist                  # App configuration
```

## Privacy

Online Now is designed with privacy as a core principle:

- No user accounts required
- No data collection or analytics
- No third-party SDKs
- All data stored locally on your device
- No background activity or automatic polling

## Architecture

The app is built using:

- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for state management
- **Network Framework**: Apple's NWPathMonitor for connection monitoring
- **URLSession**: Native networking for reachability and speed tests
- **UserDefaults**: Local data persistence

## License

This project is open source and available under the MIT License.

## App Store

**One-Line Summary**: 
Online Now lets you instantly check if your internet works, see how fast it is, and review past results — all privately, directly on your device.
