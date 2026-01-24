# Online Now

An iOS app that checks in real-time if you have an internet connection or not.

## Features

- **Real-time connectivity monitoring**: Instantly detects changes in internet connectivity
- **Visual feedback**: Clear visual indicators with color-coded status (green for online, red for offline)
- **Connection type detection**: Shows whether you're connected via WiFi, Cellular, or Ethernet
- **SwiftUI interface**: Modern, clean user interface built with SwiftUI
- **Network framework**: Uses Apple's native Network framework for reliable connectivity detection

## Requirements

- iOS 15.0 or later
- Xcode 13.0 or later
- Swift 5.9 or later

## Installation

### Using Swift Package Manager

Add the package to your Xcode project:

1. In Xcode, select File → Add Packages...
2. Enter the repository URL
3. Select the version you want to use

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/GDemay/Online-now.git", from: "1.0.0")
]
```

## Usage

### As a standalone app

The app can be built and run directly in Xcode. Simply open the project and run it on a simulator or device.

### As a library

You can use the `NetworkMonitor` class in your own iOS projects:

```swift
import OnlineNow

class MyViewController: UIViewController {
    private let networkMonitor = NetworkMonitor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        networkMonitor.start()
        
        // Observe connectivity changes
        networkMonitor.$isConnected
            .sink { isConnected in
                print("Internet connection: \(isConnected ? "Online" : "Offline")")
            }
            .store(in: &cancellables)
    }
    
    deinit {
        networkMonitor.stop()
    }
}
```

Or use the SwiftUI view directly:

```swift
import SwiftUI
import OnlineNow

struct ContentView: View {
    var body: some View {
        ConnectivityStatusView()
    }
}
```

## How It Works

The app uses Apple's `Network` framework to monitor network path updates. The `NetworkMonitor` class:

1. Creates an `NWPathMonitor` instance
2. Monitors path updates on a background queue
3. Updates published properties on the main queue when connectivity changes
4. Detects the type of connection (WiFi, Cellular, Ethernet)

The UI automatically updates when connectivity status changes, providing instant visual feedback to the user.

## Testing

To test the app's connectivity detection:

1. Run the app on a physical device or simulator
2. Toggle airplane mode on/off
3. Switch between WiFi and cellular data
4. Observe the real-time status updates

## License

This project is available for use under standard open source practices.

## Author

GDemay
