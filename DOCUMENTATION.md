# Online Now - Implementation Documentation

## Overview

This document provides detailed technical information about the Online Now iOS app implementation.

## Architecture

### MVVM Pattern with SwiftUI

The app follows the Model-View-ViewModel pattern using SwiftUI and Combine:

- **Models**: Pure data structures (`CheckResult`, `ConnectionStatus`)
- **Views**: SwiftUI views (`ContentView`, `HistoryView`)
- **ViewModels**: ObservableObjects (`NetworkMonitor`, `HistoryManager`, `SpeedTestService`)

### State Management

State is managed using SwiftUI's property wrappers:
- `@StateObject`: For view-owned observable objects
- `@EnvironmentObject`: For shared app-wide state
- `@State`: For view-local state
- `@Published`: For observable properties

### Data Flow

```
User Action → ContentView
    ↓
NetworkMonitor.checkConnection()
    ↓
URLSession.data() [Reachability Test]
    ↓
SpeedTestService.measureSpeed()
    ↓
URLSession.data() [Speed Test]
    ↓
HistoryManager.saveCheck()
    ↓
UserDefaults [Persistence]
    ↓
UI Update via @Published
```

## Core Components

### NetworkMonitor

**Purpose**: Real-time network connection monitoring and reachability testing

**Key Features**:
- Uses `NWPathMonitor` for connection type detection
- Performs actual internet reachability check (not just network presence)
- Tests against Apple's connectivity test endpoint
- Distinguishes Wi-Fi, Cellular, and No Connection states

**Implementation Details**:
```swift
// Monitors network path changes
monitor.pathUpdateHandler = { path in
    // Update connection type and status
}

// Performs actual internet check
func checkConnection() async -> (isOnline: Bool, connectionType: ConnectionType)
```

### SpeedTestService

**Purpose**: Measure effective download speed

**Key Features**:
- Downloads 512KB test file (minimal data usage)
- Calculates speed in Mbps
- Provides confidence ratings
- Caps at 1000 Mbps to avoid outliers

**Implementation Details**:
```swift
// Download test file and measure duration
let startTime = Date()
let (data, _) = try await URLSession.shared.data(from: url)
let duration = Date().timeIntervalSince(startTime)

// Calculate Mbps
let speedMbps = (bytes * 8 / 1_000_000) / duration
```

### HistoryManager

**Purpose**: Local data persistence and history management

**Key Features**:
- Stores up to 1000 historical checks
- Uses UserDefaults for simple persistence
- Provides statistics (total checks, average speed)
- Thread-safe with @MainActor

**Data Structure**:
```swift
struct CheckResult: Codable {
    let id: UUID
    let timestamp: Date
    let connectionType: ConnectionType
    let isOnline: Bool
    let speedMbps: Double?
}
```

## User Interface

### ContentView

Main screen showing:
1. **Status Icon**: Dynamic SF Symbol based on connection type
2. **Background Gradient**: Color-coded (Green=Online, Red=Offline, Blue=Checking)
3. **Status Text**: Current connection state
4. **Speed Display**: Measured speed with confidence rating
5. **Last Check Info**: Relative time since last check
6. **Check Button**: Manual refresh trigger
7. **History Button**: Access to history view

### HistoryView

History screen showing:
1. **Summary Section**: Total checks and average speed statistics
2. **Recent Checks List**: Scrollable list of all checks
3. **Clear Button**: Option to delete all history
4. **Empty State**: Helpful message when no history exists

### Accessibility

**VoiceOver Support**:
- All interactive elements have descriptive labels
- Status icons have accessibility labels
- Speed readings are read as complete sentences
- History rows combine information for clear context

**Dynamic Type**:
- All text scales with system font size
- Layout adapts to larger text sizes
- No fixed text sizes (uses semantic sizes)

## Privacy Implementation

### No Data Collection
- No analytics frameworks
- No crash reporting
- No user tracking
- No advertising SDKs

### Local-Only Storage
- All data stored in UserDefaults on device
- No cloud sync
- No external servers (except for testing)
- No user accounts

### Network Requests
Only two types of network requests are made:
1. **Reachability Check**: `https://www.apple.com/library/test/success.html`
2. **Speed Test**: `https://httpbin.org/bytes/512000`

Both are standard, privacy-respecting endpoints.

## Performance Considerations

### Battery Optimization
- No background activity
- No location services
- No continuous monitoring
- Tests run only on user request

### Data Usage
- Reachability check: ~1KB
- Speed test: 512KB
- Total per check: ~513KB
- No automatic checks

### Memory Management
- History limited to 1000 items
- Automatic cleanup of old entries
- Lightweight data structures
- Proper async/await usage

## Testing Recommendations

### Manual Testing Checklist

#### Connection States
- [ ] Test with Wi-Fi connection
- [ ] Test with Cellular connection
- [ ] Test with no connection
- [ ] Test with VPN enabled
- [ ] Test airplane mode

#### Speed Testing
- [ ] Measure speed on fast Wi-Fi (>100 Mbps)
- [ ] Measure speed on slow connection (<5 Mbps)
- [ ] Verify speed accuracy with known connection
- [ ] Test with poor/unstable connection

#### History
- [ ] Verify history saves correctly
- [ ] Check history persists after app restart
- [ ] Test clear history functionality
- [ ] Verify statistics calculations

#### Accessibility
- [ ] Enable VoiceOver and navigate app
- [ ] Test with maximum Dynamic Type size
- [ ] Verify all buttons are accessible
- [ ] Check color contrast in all states

#### Edge Cases
- [ ] Switch between Wi-Fi and Cellular mid-check
- [ ] Test with very slow network (>30s timeout)
- [ ] Rapid repeated checks
- [ ] App backgrounding during check

## Deployment Checklist

### Before App Store Submission

1. **Update Version Numbers**
   - CFBundleShortVersionString in Info.plist
   - CFBundleVersion in Info.plist

2. **Add App Icons**
   - All required sizes in Assets.xcassets
   - 1024x1024 for App Store

3. **Test on Real Devices**
   - iPhone (various sizes)
   - iPad
   - Different iOS versions (15.0+)

4. **Privacy Labels**
   - Data Not Collected: ✓
   - Data Not Tracked: ✓
   - Data Not Linked to User: ✓

5. **App Store Assets**
   - Screenshots for all device sizes
   - App preview video (optional)
   - Description highlighting privacy
   - Keywords: internet, speed test, network, connection, privacy

6. **Review Guidelines**
   - Verify no private APIs used
   - Check all string localizations
   - Test with Low Power Mode enabled
   - Verify no crash scenarios

## Potential Enhancements

### Future Features (Out of Scope)
- Export history as CSV
- Notifications for connection changes
- Widget support
- Charts/graphs of speed history
- Multiple test server options
- Upload speed testing
- Ping/latency measurements

### Code Improvements
- Unit tests for services
- UI tests for main flows
- Localization support
- iPad-optimized layout
- Dark mode optimization
- Custom app icon themes

## Support & Troubleshooting

### Common Issues

**Speed test fails**:
- Check internet connection
- Verify firewall/VPN settings
- Test server may be temporarily unavailable

**Inaccurate results**:
- Speed tests are estimates only
- Network conditions vary constantly
- Single test may not represent typical speed

**History not saving**:
- Check device storage availability
- Verify app has not been offloaded

## License

MIT License - See LICENSE file for details

## Contact

For issues or questions about this implementation, please open an issue on GitHub.
