# Apple Pay Tipping Setup Guide

This guide walks you through setting up Apple Pay tipping in App Store Connect for OnlineNow.

## 🎯 What's Implemented

The app now includes:
- ✅ **One donation option**: $1 donation
- ✅ **Contextual prompts**: After first speed test, frequent use, etc.
- ✅ **Beautiful UI**: Modern tip jar with gratitude messaging
- ✅ **StoreKit 2**: Modern async/await implementation
- ✅ **Local testing**: Configuration.storekit for Xcode testing

---

## 📋 Step 1: Create In-App Purchase Products

### 1.1 Access App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → Select **Online Now**
3. Click **In-App Purchases** in the left sidebar
4. Click the **+** button to create a new in-app purchase

### 1.2 Create Donation Product

1. **Type**: Consumable
2. **Reference Name**: `donation`
3. **Product ID**: `onlinenow.gdemay`
4. **Price**: Select **Tier 1** ($0.99 USD)
5. **Localization** (English - U.S.):
   - **Display Name**: `Donation`
   - **Description**: `Support OnlineNow development with a donation.`
6. **Review Information**:
   - **Screenshot**: Take a screenshot of the tip jar (use preview mode)
   - **Review Notes**: "Consumable donation to support app development. No content unlocked."
7. Click **Save**

### 1.3 Submit Product for Review

1. Click **Submit for Review** on your donation product
2. The product will be reviewed along with your app submission

---

## 🧪 Step 2: Test Locally (Before App Store Submission)

### 2.1 Use StoreKit Configuration File

The app includes `Configuration.storekit` for local testing:

1. Open the project in Xcode
2. Run the app in the simulator or on a device
3. In Xcode menu: **Debug** → **StoreKit** → **Configuration File** → Select `Configuration.storekit`
4. Tap the coffee cup icon in the app to open the tip jar
5. Test purchasing the donation
6. Verify the thank you message appears

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
- Donation is pure gratitude, no benefits provided

To test:
1. Complete a speed test (tap the large logo)
2. A tip prompt may appear after first speed test
3. Tap coffee cup icon in top-left to access tip jar
4. All features work without donating
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
4. Upload to the in-app purchase product

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
3. Track total donations received

### Track in Analytics (Optional Enhancement)

Consider adding analytics to track:
- How many users see tip prompts
- Conversion rate per trigger (first speed test, frequent user, etc.)
- Average tip amount per user
- Supporter retention

---

## 💡 Tips for Success

### Maximize Donations

1. **Timing is everything**: Prompts appear after positive moments (successful speed test)
2. **Show value first**: Users see the app's value before being asked to donate
3. **Make it optional**: Never block features behind donations
4. **Show gratitude**: "Thanks for supporting OnlineNow development"

### Future Enhancements

Consider adding:
- 🔜 Multiple donation tiers ($1, $5, $10)
- 🔜 Custom app icons for supporters
- 🔜 Name in credits section

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

- [ ] Donation product created in App Store Connect (ID: onlinenow.gdemay)
- [ ] Product submitted for review
- [ ] Tested with Configuration.storekit locally
- [ ] Tested with sandbox account
- [ ] Screenshot taken for the product
- [ ] App description mentions donations (optional)
- [ ] Privacy nutrition label updated
- [ ] App review notes include purchase testing instructions

**You're ready to launch! 🚀**
