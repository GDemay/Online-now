> Historical first-submission notes. For the 1.2.0 candidate, use [AUDIT.md](AUDIT.md) and [TIPPING_SETUP_GUIDE.md](TIPPING_SETUP_GUIDE.md). The checklist below is not evidence of current release readiness.

# App Store Submission Guide

This document provides all the information and steps required to publish **Online Now** on the Apple App Store.

---

## 📋 Pre-Submission Checklist

### ✅ Technical Requirements (Completed)

| Requirement | Status | File |
|-------------|--------|------|
| Bundle Identifier | ✅ `com.gdemay.onlinenow` | `project.yml` |
| Marketing Version | ✅ `1.0.0` | `project.yml` |
| Build Number | ✅ `1` | `project.yml` |
| Development Team | ✅ `MV634X2D7X` | `project.yml` |
| Deployment Target | ✅ iOS 17.0 | `project.yml` |
| App Icon (1024x1024) | ✅ | `App/Assets.xcassets/AppIcon.appiconset/` |
| Privacy Manifest | ✅ | `Sources/OnlineNow/PrivacyInfo.xcprivacy` |
| Export Compliance | ✅ `ITSAppUsesNonExemptEncryption: NO` | `App/Info.plist` |
| Required Device Capabilities | ✅ `arm64` | `App/Info.plist` |
| App Category | ✅ Utilities | `App/Info.plist` |

---

## 🏪 App Store Connect Setup

### 1. Create App Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: `Online Now`
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: `com.gdemay.onlinenow`
   - **SKU**: `onlinenow-ios-001`

### 2. App Information

| Field | Suggested Value |
|-------|-----------------|
| **Name** | Online Now |
| **Subtitle** | Network Status Monitor |
| **Category** | Utilities |
| **Content Rights** | Does not contain third-party content |
| **Age Rating** | 4+ |

### 3. App Description

```
Online Now is your essential network connectivity companion. Monitor your internet connection status in real-time with a beautiful, intuitive interface.

KEY FEATURES:
• Real-time connectivity monitoring
• Connection type detection (WiFi, Cellular, Ethernet)
• VPN status detection
• Network quality indicators
• Connection history tracking
• Speed test functionality
• Low Data Mode awareness

PERFECT FOR:
• Troubleshooting connection issues
• Monitoring network reliability
• Understanding your connectivity patterns
• Ensuring you're always online when it matters

Online Now uses Apple's Network framework for accurate, battery-efficient monitoring. No data is collected or transmitted - your privacy is fully protected.

Requires iOS 17.0 or later.
```

### 4. Keywords (100 character limit)

```
network,connectivity,wifi,internet,connection,status,monitor,speed,test,vpn,cellular
```

### 5. Support & Marketing URLs

| Field | URL |
|-------|-----|
| **Support URL** | `https://gdemay.github.io/Online-now/support.html` |
| **Marketing URL** | `https://gdemay.github.io/Online-now/` |
| **Privacy Policy URL** | `https://gdemay.github.io/Online-now/privacy.html` |

---

## 🔒 Privacy Policy

✅ **Privacy Policy Created**: Your privacy policy is ready at `docs/privacy.html`

After enabling GitHub Pages (see below), your privacy policy will be live at:
**https://gdemay.github.io/Online-now/privacy.html**

### Enable GitHub Pages

1. Go to your repository on GitHub: https://github.com/GDemay/Online-now
2. Click **Settings** → **Pages** (in the left sidebar)
3. Under "Source", select **Deploy from a branch**
4. Select **main** branch and **/docs** folder
5. Click **Save**
6. Wait 1-2 minutes for deployment
7. Your site will be live at: https://gdemay.github.io/Online-now/

### Privacy Policy Content

```
Privacy Policy for Online Now

Last updated: January 2026

Online Now ("the App") is committed to protecting your privacy.

DATA COLLECTION
The App does NOT collect, store, or transmit any personal data. All network
monitoring is performed locally on your device.

THIRD-PARTY SERVICES
The App does not integrate any third-party analytics, advertising, or
tracking services.

NETWORK ACCESS
The App monitors your device's network connectivity status using Apple's
Network framework. This information is displayed locally and is not shared.

CONTACT
For questions about this privacy policy, please visit:
https://github.com/GDemay/Online-now/issues
```

**Privacy Policy URL**: Add to App Store Connect → App Information → Privacy Policy URL

---

## 📸 Screenshots Required

### iPhone Screenshots (Required)
| Device | Resolution | Quantity |
|--------|------------|----------|
| iPhone 6.9" (iPhone 16 Pro Max) | 1320 x 2868 | 1-10 |
| iPhone 6.7" (iPhone 15 Pro Max) | 1290 x 2796 | 1-10 |
| iPhone 6.5" (iPhone 14 Plus) | 1284 x 2778 | 1-10 |
| iPhone 5.5" (iPhone 8 Plus) | 1242 x 2208 | 1-10 |

### iPad Screenshots (Required if supporting iPad)
| Device | Resolution | Quantity |
|--------|------------|----------|
| iPad Pro 12.9" | 2048 x 2732 | 1-10 |
| iPad Pro 11" | 1668 x 2388 | 1-10 |

### Screenshot Suggestions
1. **Main View**: Show connectivity status (Connected/Disconnected)
2. **Connection Details**: Display WiFi/Cellular/VPN status
3. **History View**: Show connection history timeline
4. **Speed Test**: Display speed test results
5. **Settings/Stats**: Show detailed network statistics

---

## 🎥 App Preview (Optional but Recommended)

- **Format**: H.264, 30 fps
- **Duration**: 15-30 seconds
- **Resolution**: Same as screenshot sizes

---

## 🚀 Build & Upload Process

### Step 1: Archive the App

```bash
# Navigate to project directory
cd /Users/gdemay/Documents/Saas/Online-now

# Generate Xcode project (if using XcodeGen)
xcodegen generate

# Open in Xcode
open OnlineNow.xcodeproj

# In Xcode:
# 1. Select "Any iOS Device (arm64)" as destination
# 2. Product → Archive
# 3. Wait for archive to complete
```

### Step 2: Upload to App Store Connect

1. In Xcode Organizer (Window → Organizer)
2. Select the archive
3. Click **Distribute App**
4. Choose **App Store Connect**
5. Select **Upload**
6. Follow prompts for signing

### Step 3: Submit for Review

1. Go to App Store Connect
2. Select your app
3. Click **+ Version or Platform** (if needed)
4. Fill in all required fields
5. Add screenshots
6. Click **Submit for Review**

---

## ⚠️ Common Rejection Reasons & Solutions

| Issue | Solution |
|-------|----------|
| Missing privacy policy | Add privacy policy URL in App Store Connect |
| Incomplete metadata | Fill all required fields including screenshots |
| Crashes on launch | Test thoroughly on physical devices |
| Guideline 4.2 (Minimum Functionality) | Ensure app provides meaningful functionality |
| Missing export compliance | ✅ Already added `ITSAppUsesNonExemptEncryption: NO` |

---

## 📱 App Review Guidelines Compliance

### Guideline 5.1 - Privacy
- ✅ Privacy manifest included
- ✅ No data collection
- ✅ No tracking

### Guideline 2.1 - App Completeness
- ✅ App is fully functional
- ✅ All features work as described

### Guideline 4.0 - Design
- ✅ Native iOS design patterns
- ✅ SwiftUI implementation

### Guideline 5.1.1 - Data Collection
- ✅ `NSPrivacyCollectedDataTypes` is empty (no data collected)
- ✅ `NSPrivacyTracking` is `false`

---

## 📞 Support Contact

For App Store review team contact:
- **Email**: Set up a support email address
- **Phone** (optional): Provide for reviewer contact

---

## 📅 Review Timeline

- **Standard Review**: 24-48 hours (typical)
- **Expedited Review**: Request via App Store Connect if critical fix needed

---

## ✅ Final Checklist Before Submission

- [ ] App tested on physical devices (iPhone & iPad)
- [ ] All screenshots uploaded (correct resolutions)
- [ ] Privacy policy URL accessible
- [ ] Support URL accessible
- [ ] App description complete
- [ ] Keywords optimized
- [ ] Age rating set (4+)
- [ ] Build uploaded via Xcode
- [ ] Export compliance answered
- [ ] Content rights confirmed
