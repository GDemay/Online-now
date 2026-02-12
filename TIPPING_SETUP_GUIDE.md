# Apple Pay Tipping Setup Guide

This guide walks you through setting up Apple Pay tipping in App Store Connect for OnlineNow.

## 🎯 What's Implemented

The app now includes:
- ✅ **Three tip tiers**: Small ($2), Medium ($5), Large ($10)
- ✅ **Contextual prompts**: After first speed test, frequent use, etc.
- ✅ **Supporter benefits**: Name in credits, custom icons, beta access
- ✅ **Beautiful UI**: Modern tip jar with impact messaging
- ✅ **StoreKit 2**: Modern async/await implementation
- ✅ **Local testing**: Configuration.storekit for Xcode testing

---

## 📋 Step 1: Create In-App Purchase Products

### 1.1 Access App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → Select **Online Now**
3. Click **In-App Purchases** in the left sidebar
4. Click the **+** button to create a new in-app purchase

### 1.2 Create Small Tip ($2)

1. **Type**: Consumable
2. **Reference Name**: `Small Tip ($2)`
3. **Product ID**: `com.gdemay.onlinenow.tip.small`
4. **Price**: Select **Tier 2** ($1.99 USD)
5. **Localization** (English - U.S.):
   - **Display Name**: `Small Tip`
   - **Description**: `Buy me a coffee! Support development of OnlineNow.`
6. **Review Information**:
   - **Screenshot**: Take a screenshot of the tip jar (use preview mode)
   - **Review Notes**: "Consumable tip to support app development. No content unlocked."
7. Click **Save**

### 1.3 Create Medium Tip ($5)

1. **Type**: Consumable
2. **Reference Name**: `Medium Tip ($5)`
3. **Product ID**: `com.gdemay.onlinenow.tip.medium`
4. **Price**: Select **Tier 5** ($4.99 USD)
5. **Localization** (English - U.S.):
   - **Display Name**: `Medium Tip`
   - **Description**: `Buy me lunch! Your support means a lot.`
6. **Review Information**:
   - **Screenshot**: Same tip jar screenshot
   - **Review Notes**: "Consumable tip to support app development. Unlocks supporter badge."
7. Click **Save**

### 1.4 Create Large Tip ($10)

1. **Type**: Consumable
2. **Reference Name**: `Large Tip ($10)`
3. **Product ID**: `com.gdemay.onlinenow.tip.large`
4. **Price**: Select **Tier 10** ($9.99 USD)
5. **Localization** (English - U.S.):
   - **Display Name**: `Large Tip`
   - **Description**: `Generous supporter! Unlock exclusive benefits.`
6. **Review Information**:
   - **Screenshot**: Same tip jar screenshot
   - **Review Notes**: "Consumable tip to support app development. Unlocks power supporter benefits."
7. Click **Save**

### 1.5 Submit Products for Review

1. For each product, click **Submit for Review**
2. Products will be reviewed along with your app submission

---

## 🧪 Step 2: Test Locally (Before App Store Submission)

### 2.1 Use StoreKit Configuration File

The app includes `Configuration.storekit` for local testing:

1. Open the project in Xcode
2. Run the app in the simulator or on a device
3. In Xcode menu: **Debug** → **StoreKit** → **Configuration File** → Select `Configuration.storekit`
4. Tap the coffee cup icon in the app to open the tip jar
5. Test purchasing all three tip tiers
6. Verify supporter badges appear correctly

### 2.2 Test Sandbox Environment

Before going live, test with sandbox accounts:

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Users and Access** → **Sandbox Testers**
3. Create a new sandbox tester account
4. Sign out of your Apple ID on your device (Settings → App Store)
5. Run your app from Xcode
6. When prompted to sign in, use your sandbox tester account
7. Test all purchase flows

**Important**: Never use your real Apple ID for testing purchases!

---

## 📱 Step 3: Integrate with App Submission

### 3.1 Update App Description

Add this to your App Store description:

```
💙 SUPPORT THE DEVELOPER
Love OnlineNow? Support development with an optional tip! Your generosity helps fund new features like ISP comparison, WiFi location ratings, and advanced analytics.

Supporter Benefits:
• $2+: Name in credits
• $5+: Custom app icons
• $10+: Beta feature access
```

### 3.2 Update App Review Notes

Add this to your App Review Notes:

```
IN-APP PURCHASES:
This app includes optional tipping functionality:
- Three consumable tips: $2, $5, $10
- Tips support ongoing development
- No content is locked behind paywalls
- Supporter benefits are cosmetic (badges, app icons)

To test:
1. Complete a speed test (tap the large logo)
2. A tip prompt may appear after first speed test
3. Tap coffee cup icon in top-left to access tip jar
4. All features work without tipping
```

### 3.3 Privacy Nutrition Label

Update your privacy nutrition label in App Store Connect:

1. Go to **App Privacy** section
2. Add **Purchases** data type:
   - **Purchase History**: Used for tracking supporter status
   - **Linked to User**: Yes
   - **Used for Tracking**: No

---

## 🎨 Step 4: Take Screenshots for Review

Apple requires screenshots of in-app purchases:

### 4.1 Screenshot the Tip Jar

1. Run the app in simulator (iPhone 15 Pro)
2. Tap the coffee cup icon in top-left
3. Take a screenshot (Cmd+S)
4. Upload to each in-app purchase product

### 4.2 Screenshot After Purchase

1. Make a test purchase
2. Screenshot the "Thank You" alert
3. Keep for App Review if requested

---

## ⚡ Step 5: Monitor Performance

After launch, monitor tipping performance:

### Track in App Store Connect

1. **Sales and Trends** → Filter by **In-App Purchases**
2. Monitor conversion rates
3. Track which tip tier is most popular

### Track in Analytics (Optional Enhancement)

Consider adding analytics to track:
- How many users see tip prompts
- Conversion rate per trigger (first speed test, frequent user, etc.)
- Average tip amount per user
- Supporter retention

---

## 💡 Tips for Success

### Maximize Tip Conversions

1. **Timing is everything**: Prompts appear after positive moments (successful speed test)
2. **Show value first**: Users see the app's value before being asked to tip
3. **Make it optional**: Never block features behind tips
4. **Show impact**: "Your tip helps fund ISP comparison features"
5. **Reward supporters**: Badges and benefits create social proof

### Supporter Benefits Roadmap

Current benefits:
- ✅ Name in credits (coming soon)
- ✅ Supporter badges
- 🔜 Custom app icons (implement next)
- 🔜 Beta feature access

To implement custom app icons:
1. Add alternate app icons to Assets.xcassets
2. Update Info.plist with `CFBundleIcons`
3. Add icon picker in settings

### Future Monetization

Once tipping is established, consider:
- Premium subscription ($4.99/month) for unlimited locations
- ISP comparison as premium feature
- WiFi location ratings for power users
- Family monitoring dashboard

---

## 🐛 Troubleshooting

### "Products not found"
- Ensure products are approved in App Store Connect
- Wait 2-24 hours after creating products
- Verify Bundle ID matches exactly
- Check internet connection

### "Cannot connect to iTunes Store"
- Sign out of App Store on device
- Sign in with sandbox tester account
- Ensure StoreKit testing is enabled in scheme

### "Purchase failed"
- Check product IDs match exactly (case-sensitive)
- Verify products are approved
- Ensure app is signed with correct team
- Check Xcode console for detailed error

---

## 📞 Support

If you encounter issues:
1. Check Xcode console for error messages
2. Verify all product IDs match exactly
3. Ensure products are approved in App Store Connect
4. Test with sandbox account first
5. Contact Apple Developer Support if needed

---

## ✅ Launch Checklist

Before submitting to App Store:

- [ ] All three tip products created in App Store Connect
- [ ] Products submitted for review
- [ ] Tested with Configuration.storekit locally
- [ ] Tested with sandbox account
- [ ] Screenshots taken for each product
- [ ] App description updated with tipping info
- [ ] Privacy nutrition label updated
- [ ] App review notes include purchase testing instructions
- [ ] Supporter benefits clearly communicated

**You're ready to launch! 🚀**
