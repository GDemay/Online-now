# 🚀 First-Time App Store Publishing Guide

This guide walks you through every step to publish Online Now on the Apple App Store for the first time.

---

## 📋 What You'll Need

Before you start, make sure you have:

- [ ] **Apple Developer Account** ($99/year) - [Enroll here](https://developer.apple.com/programs/enroll/)
- [ ] **Mac with Xcode 15+** installed
- [ ] **Physical iOS device** for testing (recommended)
- [ ] **App icon** (1024x1024 PNG) ✅ Already included
- [ ] **Screenshots** for App Store (see sizes below)

---

## Step 1: Verify Your Apple Developer Account

1. Go to [developer.apple.com](https://developer.apple.com)
2. Sign in with your Apple ID
3. If not enrolled, click **Enroll** and follow the process
4. Wait for approval (usually 24-48 hours for individuals)

Once approved, you'll have access to:
- App Store Connect
- Certificates, Identifiers & Profiles
- Developer documentation

---

## Step 2: Create App ID & Certificates

### 2.1 Create an App ID

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Click **Identifiers** → **+** button
3. Select **App IDs** → Continue
4. Select **App** → Continue
5. Fill in:
   - **Description**: `Online Now`
   - **Bundle ID**: Select **Explicit** and enter `com.gdemay.onlinenow`
6. Scroll down - no capabilities needed for this app
7. Click **Continue** → **Register**

### 2.2 Create Distribution Certificate (if you don't have one)

1. Go to **Certificates** → **+** button
2. Select **Apple Distribution** → Continue
3. Follow the instructions to create a Certificate Signing Request (CSR)
4. Upload the CSR and download the certificate
5. Double-click to install in Keychain

---

## Step 3: Enable GitHub Pages for Privacy Policy

Your privacy policy and support pages are ready in the `docs/` folder. Enable GitHub Pages:

1. Push your changes to GitHub:
   ```bash
   git add .
   git commit -m "Add App Store submission files"
   git push origin main
   ```

2. Go to [github.com/GDemay/Online-now](https://github.com/GDemay/Online-now)

3. Click **Settings** (top menu) → **Pages** (left sidebar)

4. Under **Source**:
   - Select **Deploy from a branch**
   - Branch: **main**
   - Folder: **/docs**

5. Click **Save**

6. Wait 1-2 minutes, then verify:
   - https://gdemay.github.io/Online-now/ (landing page)
   - https://gdemay.github.io/Online-now/privacy.html (privacy policy)
   - https://gdemay.github.io/Online-now/support.html (support page)

---

## Step 4: Create App Store Connect Record

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Apps** → **+** → **New App**
3. Fill in the form:

   | Field | Value |
   |-------|-------|
   | Platforms | iOS |
   | Name | Online Now |
   | Primary Language | English (U.S.) |
   | Bundle ID | com.gdemay.onlinenow |
   | SKU | onlinenow-ios-001 |
   | User Access | Full Access |

4. Click **Create**

---

## Step 5: Fill in App Information

### 5.1 App Information Tab

Navigate to **App Information** and fill in:

| Field | Value |
|-------|-------|
| Subtitle | Network Status Monitor |
| Category | Utilities |
| Content Rights | This app does not contain third-party content |

### 5.2 Privacy Policy

1. Scroll to **Privacy Policy URL**
2. Enter: `https://gdemay.github.io/Online-now/privacy.html`

### 5.3 Age Rating

Click **Set Up Age Rating** and answer the questionnaire:

- All answers should be **No** (no objectionable content)
- Result will be **4+**

---

## Step 6: Prepare Version Information

### 6.1 App Description

Go to **iOS App** → **Version Information**:

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

### 6.2 Keywords

```
network,connectivity,wifi,internet,connection,status,monitor,speed,test,vpn,cellular
```

### 6.3 Support & Marketing URLs

| Field | URL |
|-------|-----|
| Support URL | https://gdemay.github.io/Online-now/support.html |
| Marketing URL | https://gdemay.github.io/Online-now/ |

### 6.4 What's New (Release Notes)

```
Initial release of Online Now!

• Real-time network monitoring
• Connection type detection
• VPN status tracking
• Speed testing
• Connection history
```

---

## Step 7: Take Screenshots

You need screenshots for each device size you support.

### Required Screenshot Sizes

| Device | Resolution | Required |
|--------|------------|----------|
| iPhone 6.9" Display | 1320 x 2868 | Yes (for iPhone 16 Pro Max) |
| iPhone 6.7" Display | 1290 x 2796 | Yes (for iPhone 15 Pro Max) |
| iPhone 6.5" Display | 1284 x 2778 | Yes (for older Pro Max models) |
| iPhone 5.5" Display | 1242 x 2208 | Optional |
| iPad Pro 12.9" | 2048 x 2732 | Yes (if iPad supported) |

### How to Take Screenshots

1. Run the app in Simulator:
   ```bash
   cd /Users/gdemay/Documents/Saas/Online-now
   open OnlineNow.xcodeproj
   ```

2. Select each device size in Xcode
3. Run the app (⌘R)
4. Press ⌘S in Simulator to take a screenshot
5. Screenshots save to Desktop

### Recommended Screenshots

1. **Main View (Online)** - Show green "You're Online" status
2. **Main View (Offline)** - Show red "You're Offline" status
3. **Speed Test** - Show speed test results
4. **Connection Details** - Show WiFi/VPN/connection info
5. **History View** - Show connection history

---

## Step 8: Build and Upload

### 8.1 Configure Signing in Xcode

1. Open `OnlineNow.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select **OnlineNow** target
4. Go to **Signing & Capabilities** tab
5. Check **Automatically manage signing**
6. Select your **Team** (your Apple Developer account)
7. Xcode will create the provisioning profile automatically

### 8.2 Archive the App

1. In Xcode, select **Any iOS Device (arm64)** as the destination
2. Menu: **Product** → **Archive**
3. Wait for the archive to complete
4. The Organizer window will open automatically

### 8.3 Upload to App Store Connect

1. In Organizer, select your archive
2. Click **Distribute App**
3. Select **App Store Connect** → Next
4. Select **Upload** → Next
5. Keep default options checked:
   - ✅ Upload your app's symbols
   - ✅ Manage version and build number
6. Click **Next**
7. Select your Distribution certificate
8. Click **Upload**
9. Wait for upload to complete (5-10 minutes)

---

## Step 9: Submit for Review

### 9.1 Select the Build

1. Go to App Store Connect → Your App → iOS App
2. Scroll to **Build** section
3. Click **Select a Build**
4. Choose the build you just uploaded
5. Click **Done**

### 9.2 Export Compliance

When prompted:
- **Does this app use encryption?** → **No**
  (We already set `ITSAppUsesNonExemptEncryption` to `NO`)

### 9.3 App Review Information

Fill in contact info for the review team:

| Field | Value |
|-------|-------|
| First Name | Your first name |
| Last Name | Your last name |
| Phone | Your phone number |
| Email | Your email |

Notes for Review:
```
This app monitors network connectivity status using Apple's Network framework.
To test:
1. Launch the app to see your current connection status
2. Toggle WiFi/Airplane mode to see real-time updates
3. Tap the speed button to run a speed test
No login or special setup required.
```

### 9.4 Submit

1. Click **Add for Review**
2. Review all information
3. Click **Submit to App Review**

---

## Step 10: Wait for Review

- **Typical review time**: 24-48 hours
- You'll receive an email when review is complete
- Check App Store Connect for status updates

### Possible Outcomes

| Status | Meaning | Action |
|--------|---------|--------|
| In Review | Apple is reviewing | Wait |
| Approved | Ready for sale! | 🎉 Celebrate! |
| Rejected | Issues found | Read feedback, fix, resubmit |

---

## 🎉 Post-Approval Checklist

Once approved:

- [ ] Verify app appears in App Store search
- [ ] Update `docs/index.html` with your real App Store link
- [ ] Share on social media
- [ ] Monitor reviews and ratings
- [ ] Respond to user feedback

---

## ❓ Troubleshooting

### "No provisioning profiles found"

1. In Xcode: Preferences → Accounts → Download Manual Profiles
2. Or: Check that your Bundle ID matches exactly

### "App ID not available"

The bundle ID might be taken. Try a unique variation like:
- `com.gdemay.onlinenow.app`
- `com.yourdomain.onlinenow`

### Build upload fails

1. Check your internet connection
2. Ensure Xcode is up to date
3. Try: Xcode → Preferences → Accounts → Sign out/in

### Rejection for "Minimum Functionality"

Add more visible features or improve the description to clarify the app's value.

---

## 📞 Need Help?

- **Apple Developer Support**: [developer.apple.com/support](https://developer.apple.com/support)
- **App Review Guidelines**: [developer.apple.com/app-store/review/guidelines](https://developer.apple.com/app-store/review/guidelines)
- **Project Issues**: [github.com/GDemay/Online-now/issues](https://github.com/GDemay/Online-now/issues)
