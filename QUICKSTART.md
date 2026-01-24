# Quick Start Guide - Online Now

## For Users

### What is Online Now?

Online Now is a simple iOS app that tells you:
1. **Are you online?** (Real internet check, not just Wi-Fi icon)
2. **How fast is your connection?** (Measured in Mbps)
3. **What was your connection like earlier?** (Full history)

### How to Use

1. **Open the app** - You'll see your current connection status
2. **Tap "Check Now"** - Tests your internet and measures speed
3. **View results** - See if you're online and how fast
4. **Check history** - Tap "View History" to see past checks

That's it! No setup, no accounts, no complexity.

### Understanding Results

**Connection Types**:
- 🔵 **Wi-Fi**: Connected via wireless network
- 🟢 **Cellular**: Connected via mobile data
- 🔴 **No Connection**: Not connected to internet

**Speed Ratings**:
- < 1 Mbps: Very slow connection
- 1-5 Mbps: Slow connection
- 5-25 Mbps: Moderate connection
- 25-100 Mbps: Good connection
- 100+ Mbps: Excellent connection

### Privacy

- ✅ All data stays on your device
- ✅ No account needed
- ✅ No tracking or analytics
- ✅ You can clear history anytime

---

## For Developers

### Getting Started

**Prerequisites**:
- macOS with Xcode 15.0 or later
- iOS 15.0 SDK or later
- Basic Swift/SwiftUI knowledge

### Setup (2 minutes)

```bash
# Clone the repository
git clone https://github.com/GDemay/Online-now.git
cd Online-now

# Open in Xcode
open OnlineNow.xcodeproj

# Build and run (⌘R)
# Select iPhone simulator or connected device
```

### Project Structure

```
OnlineNow/
├── OnlineNowApp.swift           # App entry point
├── Models/                      # Data models
│   ├── ConnectionStatus.swift
│   └── CheckResult.swift
├── Services/                    # Business logic
│   ├── NetworkMonitor.swift     # Connection monitoring
│   ├── SpeedTestService.swift   # Speed testing
│   └── HistoryManager.swift     # Data persistence
└── Views/                       # UI components
    ├── ContentView.swift        # Main screen
    └── HistoryView.swift        # History screen
```

### Key Technologies

- **SwiftUI**: Modern declarative UI
- **Combine**: Reactive state management
- **NWPathMonitor**: Network connection monitoring
- **URLSession**: Network requests
- **UserDefaults**: Local data storage

### Making Changes

1. **Edit code** in Xcode
2. **Test** on simulator (⌘R)
3. **Test accessibility** with VoiceOver
4. **Commit** your changes
5. **Open pull request** on GitHub

### Common Tasks

**Add a new feature**:
1. Create feature branch
2. Implement in appropriate service/view
3. Test thoroughly
4. Update documentation
5. Submit PR

**Fix a bug**:
1. Reproduce the issue
2. Fix in code
3. Test fix works
4. Test doesn't break other features
5. Submit PR

**Improve UI**:
1. Modify SwiftUI views
2. Test on multiple device sizes
3. Test with accessibility features
4. Get feedback
5. Submit PR

### Testing Checklist

- [ ] Builds without warnings
- [ ] Runs on iOS 15.0+
- [ ] Works on iPhone (all sizes)
- [ ] Works on iPad
- [ ] VoiceOver accessible
- [ ] Supports Dynamic Type
- [ ] No crashes
- [ ] Maintains privacy (no data collection)

### Need Help?

- 📖 Read [DOCUMENTATION.md](DOCUMENTATION.md) for detailed technical info
- 🤝 Read [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
- 🐛 Open an issue on GitHub for bugs
- 💡 Open a discussion for feature ideas

---

## For Testers

### What to Test

**Connection States**:
- [ ] Wi-Fi connection
- [ ] Cellular connection (with data)
- [ ] No connection (airplane mode)
- [ ] VPN enabled
- [ ] Switch between Wi-Fi and Cellular

**Speed Testing**:
- [ ] Fast connection (>100 Mbps)
- [ ] Slow connection (<5 Mbps)
- [ ] Very slow connection (<1 Mbps)
- [ ] Unstable connection

**History**:
- [ ] History saves correctly
- [ ] History persists after restart
- [ ] Clear history works
- [ ] Statistics are accurate

**UI/UX**:
- [ ] All buttons work
- [ ] Loading states show correctly
- [ ] Colors match connection state
- [ ] Text is readable

**Accessibility**:
- [ ] VoiceOver reads everything correctly
- [ ] Works with largest text size
- [ ] All buttons are tappable
- [ ] Color contrast is sufficient

**Edge Cases**:
- [ ] Rapid repeated checks
- [ ] Switching networks mid-check
- [ ] Backgrounding during check
- [ ] Very long check times

### Reporting Issues

When you find a bug, report:
1. What you were doing
2. What you expected to happen
3. What actually happened
4. iOS version and device model
5. Screenshots/video if possible

---

## FAQ

### General

**Q: Why does it need internet access?**
A: To check if you actually have working internet and measure speed.

**Q: How much data does it use?**
A: About 512 KB per check (for speed test).

**Q: Does it run in the background?**
A: No. Only checks when you tap "Check Now".

**Q: Where is my data stored?**
A: Only on your device. Never sent anywhere.

### Technical

**Q: What speed test endpoint is used?**
A: httpbin.org/bytes/512000 (512 KB test file).

**Q: How is speed calculated?**
A: Time to download 512 KB, converted to Mbps.

**Q: Is the speed test accurate?**
A: It provides a reasonable estimate. Single tests may vary.

**Q: Why not use Apple's Network Quality API?**
A: To maintain compatibility with iOS 15.0 and give users direct control.

### Privacy

**Q: What data do you collect?**
A: None. Zero. Nothing.

**Q: Is my connection history private?**
A: Yes, it's only on your device.

**Q: Can I delete my data?**
A: Yes, tap "Clear" in History view or delete the app.

**Q: Do you track usage?**
A: No tracking whatsoever.

---

## Support

- 📧 Email: support@onlinenow-app.com
- 🐛 Issues: https://github.com/GDemay/Online-now/issues
- 💬 Discussions: https://github.com/GDemay/Online-now/discussions

---

**Welcome to Online Now! Check your connection, know your speed, protect your privacy.** 🚀
