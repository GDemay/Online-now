# App Store Submission Guide

## App Store Connect Information

### App Name
**Online Now**

### Subtitle (30 characters max)
Internet Status & Speed Tracker

### Promotional Text (170 characters max)
Check if your internet works instantly. Measure speed accurately. Track history privately. No accounts, no tracking, no background activity.

### Description

**Online Now** tells you instantly and reliably whether you are connected to the internet — and how good that connection is.

**KEY FEATURES**

✓ Instant Internet Status
Know if the internet actually works — not just if a network is present. Real reachability checks distinguish between Wi-Fi, Cellular, and No Connection.

✓ Reliable Speed Testing
Get a realistic sense of connection quality with accurate speed measurements in Mbps. Short, controlled tests that respect battery life and minimize data usage.

✓ Automatic History Tracking
Every check is automatically saved locally with date, time, connection type, and measured speed. Review how your connection performed minutes, hours, or days ago.

✓ At-a-Glance Overview
See your last check result and time since measurement immediately. Know if things changed since you last checked.

✓ Private by Design
Your network data stays yours. Always. All data stored only on your device. No accounts. No tracking. No analytics. No third-party SDKs.

✓ Simple, Focused Interface
One distraction-free screen with clear states: Checking, Online, Offline, or Measuring Speed. Manual refresh — nothing runs in the background.

✓ Battery & Data Friendly
No background activity or automatic polling. Speed tests run only when you ask. Safe to use anywhere, even on limited data plans.

✓ Built for Reliability
Handles poor networks gracefully. Works correctly with VPNs. Clear feedback when results are uncertain. No misleading or inflated numbers.

✓ Fully Accessible
Complete support for Dynamic Type, VoiceOver, and native iOS design. Respects system settings including Low Power Mode.

**WHAT ONLINE NOW IS NOT**

• Not a Speedtest clone
• Not a background monitoring tool
• Not a data-hungry analytics app

It focuses on one clear goal — helping you understand your connection — by telling you if you're online, how good that connection is, and keeping a private history.

**PRIVACY FIRST**

• Fully offline-safe
• No permissions required
• Zero data collection
• No advertising or tracking
• Complies with App Store Review Guidelines

**REQUIREMENTS**

• iOS 15.0 or later
• No internet connection required for history viewing
• Minimal data usage per check (~500KB)

### Keywords (100 characters max)
internet,network,speed,test,wifi,cellular,connection,status,monitor,check,bandwidth,ping,history

### Support URL
https://github.com/GDemay/Online-now

### Marketing URL (optional)
https://github.com/GDemay/Online-now

### Privacy Policy URL
https://github.com/GDemay/Online-now/blob/main/PRIVACY.md

## App Store Categories

**Primary Category**: Utilities

**Secondary Category**: Productivity

## Age Rating

**Rating**: 4+ (No objectionable content)

## Pricing

**Price**: Free (or paid, as per your preference)

**In-App Purchases**: None

## App Privacy

### Data Collection Practices

**Data Not Collected**: ✓

Online Now does not collect any data from users.

**Privacy Details to Declare**:
- Data Not Collected: YES
- Data Not Tracked: YES  
- Data Not Linked to User: YES

## Screenshots Requirements

### iPhone (Required sizes)

**6.7" Display (iPhone 14 Pro Max)**
- Portrait: 1290 x 2796 pixels
- Screenshots needed: 3-10

**6.5" Display (iPhone 11 Pro Max, XS Max)**
- Portrait: 1242 x 2688 pixels
- Screenshots needed: 3-10

**5.5" Display (iPhone 8 Plus)**
- Portrait: 1242 x 2208 pixels
- Screenshots needed: 3-10

### iPad (Optional but recommended)

**12.9" Display (iPad Pro 3rd/4th gen)**
- Portrait: 2048 x 2732 pixels
- Screenshots needed: 3-10

### Suggested Screenshots

1. **Main Screen - Online State**
   - Show green gradient with Wi-Fi icon
   - Display speed measurement
   - "Online" status

2. **Main Screen - Checking**
   - Show blue gradient
   - "Checking..." status
   - Progress indicator

3. **Speed Test Result**
   - Show measured speed (e.g., "45.2 Mbps")
   - Show confidence rating
   - Connection type

4. **History View**
   - Show list of past checks
   - Display summary statistics
   - Various connection types

5. **Accessibility Feature**
   - Show large text support
   - Demonstrate clear interface

## App Review Information

### Contact Information
**First Name**: Online
**Last Name**: Now Support
**Phone Number**: +1-555-ONLINE-NOW
**Email**: support@onlinenow-app.com

### Demo Account
Not required (no login functionality)

### Review Notes
```
Online Now is a privacy-focused utility that checks internet connectivity status and measures download speed.

KEY POINTS FOR REVIEW:

1. Privacy: The app makes zero data collection calls. All data is stored locally using UserDefaults.

2. Network Requests: The app only makes two types of network requests:
   - Reachability check to Apple's connectivity endpoint
   - Speed test download from httpbin.org (512KB)
   
3. No Background Activity: All checks are manual. No background processes or location tracking.

4. Accessibility: Full VoiceOver support and Dynamic Type implemented.

5. Testing: Please test with different network conditions:
   - Wi-Fi connection
   - Cellular connection
   - No connection (Airplane mode)
   
The app will display appropriate status and perform speed measurement only when online.

Thank you for reviewing Online Now!
```

## Version Release Information

### What's New in This Version (4000 characters max)

**Version 1.0**

Welcome to Online Now — your instant, reliable internet connection checker.

NEW IN THIS VERSION:
• Instant connection status checking
• Real speed measurement in Mbps
• Automatic history tracking
• Beautiful, accessible interface
• Complete privacy — zero data collection

Tell us if you're online and how fast. Nothing more, nothing less.

## Export Compliance

**Does your app use encryption?**
Answer: NO (only uses standard HTTPS which is exempt)

If YES:
- Uses only exempt algorithms (HTTPS)
- No encryption point of contact required

## Government Data Request

**Does your app have content rights requirements?**
Answer: NO

## Trademark Acknowledgment

Ensure you have rights to use:
- App name "Online Now"
- Any third-party libraries or assets

## Testing Checklist Before Submission

### Functional Testing
- [ ] App launches successfully
- [ ] Can check connection status
- [ ] Can measure speed
- [ ] History saves correctly
- [ ] History view displays correctly
- [ ] Clear history works
- [ ] App handles no internet gracefully
- [ ] App handles slow internet gracefully

### Technical Requirements
- [ ] No crashes or freezes
- [ ] Memory usage is reasonable
- [ ] Battery usage is minimal
- [ ] Works on iOS 15.0+
- [ ] Supports all iPhone sizes
- [ ] Supports iPad (if applicable)
- [ ] Supports both orientations (if applicable)

### Privacy & Security
- [ ] No analytics SDKs included
- [ ] No third-party tracking
- [ ] Data stored locally only
- [ ] HTTPS only (no HTTP)
- [ ] No private APIs used

### App Store Assets
- [ ] App icon (all sizes)
- [ ] Screenshots (all required sizes)
- [ ] Description written
- [ ] Keywords selected
- [ ] Privacy policy URL provided
- [ ] Support URL provided

### Metadata
- [ ] App name is correct
- [ ] Version number is correct (1.0)
- [ ] Build number is correct (1)
- [ ] Category is appropriate (Utilities)
- [ ] Age rating is correct (4+)

## Submission Process

1. **Archive the app** in Xcode (Product > Archive)
2. **Validate the archive** (catch issues before submission)
3. **Upload to App Store Connect**
4. **Complete all metadata** in App Store Connect
5. **Upload screenshots** for all device sizes
6. **Set pricing** and availability
7. **Submit for review**

## After Submission

**Typical Review Time**: 1-3 days

**Possible Outcomes**:
- ✓ Approved — App goes live
- ⚠ Metadata Rejected — Fix description/screenshots and resubmit
- ✗ Binary Rejected — Need to fix code and upload new build

**Common Rejection Reasons**:
- Insufficient app description
- Missing/incorrect screenshots
- Privacy policy issues
- App crashes during review
- Misleading functionality claims

## Post-Launch Checklist

- [ ] Monitor crash reports
- [ ] Check user reviews
- [ ] Respond to support emails
- [ ] Monitor app analytics (if you add them)
- [ ] Plan future updates

## Version Updates

For future updates:
1. Increment build number (2, 3, 4...)
2. Update version if needed (1.1, 1.2, 2.0)
3. Write "What's New" text
4. Test thoroughly
5. Submit as update in App Store Connect

## Resources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)

---

Good luck with your submission! 🚀
