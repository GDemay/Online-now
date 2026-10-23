# Optional tips: setup and verification

Online Now uses StoreKit 2 in-app purchases for an optional, repeatable tip. Every app feature remains free. This is an App Store purchase, not an Apple Pay integration or a charitable donation.

The separate 1.2.1 candidate restores the user-initiated Support developer
button and disables automatic prompts. Submitted free-only 1.2.0 (45) remains
unchanged. Native candidate validation and actual account-backed readiness must
be recorded separately before production donation submission; a retained
historical or local-StoreKit build does not satisfy that gate.

## Catalog and App Store Connect

The app and `Configuration.storekit` use one product:

| Field | Value |
| --- | --- |
| Bundle identifier | `com.gdemay.onlinenow` |
| Product identifier | `onlinenow.gdemay` |
| Product type | Consumable |
| Local test price | `0.99` in the local test configuration |

The live price and currency come from `Product.displayPrice`. The local test price does not set the live price. Do not rename the product identifier to fix an empty catalog without checking the actual App Store Connect product first.

Before release, verify in App Store Connect that:

- The product belongs to the exact app bundle and is available in the intended storefronts.
- Its type is Consumable, its price and localization are complete, and its review screenshot is current.
- The product is approved or submitted with the app as required by App Store Connect.
- Paid Apps agreements, tax information, and banking requirements are current.
- The app version includes the in-app purchase when submitting it for review.

These checks require App Store Connect access. Source inspection and local StoreKit tests cannot establish that the live catalog or payment account is ready.

## What the implementation does

- Shows the App Store's localized product and price. An empty or failed catalog shows an explanation and a retry action.
- Prevents simultaneous purchase attempts, verifies transactions, saves a transaction-ID ledger before finishing, and ignores repeated delivery of the same transaction.
- Listens for delayed purchase approval and recovers unfinished transactions when the app starts.
- Leaves an unverified transaction unfinished and shows a verification error.
- Treats cancellation as cancellation, and pending approval as a pending status rather than a failure or a successful payment.
- Records verified refund/revocation updates without allowing an older delivery to restore the refunded tip.
- Counts tips rather than summing prices from different currencies into a misleading US dollar total.
- Describes tips as gratitude and maintenance support. No custom icons, credits, beta access, or priority support are sold.

The ledger is local to this installation. Consumable tips are not restorable through `AppStore.sync()` after reinstalling the app. There is deliberately no Restore Purchases button. Refund updates delivered to the current installation are reflected locally; the ledger is not a server-side financial record.

Ask to Buy requests can remain pending while approval happens outside the app. A declined request does not emit a completed transaction. If a request has been declined, reopen the app before trying another tip. Approval delivered later is still deduplicated by transaction ID.

## Local testing in Xcode

1. Use a Mac with the project's supported Xcode version and open `OnlineNow.xcodeproj`.
2. Use the shared OnlineNow scheme. Its run/test setup uses `Configuration.storekit` for local testing; confirm the configuration in Scheme > Edit Scheme before running.
3. Run the iOS simulator tests, including `TippingManagerTests` and `TippingStoreKitTests`.
4. Launch the app, open the tip jar, confirm a single consumable with a localized price, purchase it twice, and confirm two tips are recorded.
5. Use Xcode's StoreKit transaction controls to check cancellation, failure, pending Ask to Buy, approval, refund, and transaction redelivery.
6. Terminate and reopen the app between purchase confirmation and fulfillment to check unfinished recovery.
7. Check large text, VoiceOver labels, dark mode, and that Close remains available while a request is pending.
8. Disable the local catalog and verify that an unavailable or unreachable App Store produces an explanation and retry action rather than a blank sheet.

The pure Foundation ledger tests cover duplicate delivery, repeat consumables, refunds, out-of-order refund delivery, and persistence. Apple tests exercise persisted manager state and the local StoreKit flow. Passing local tests does not prove live payments work.

## Sandbox and TestFlight release check

Use a development build with the local StoreKit configuration disabled, or a TestFlight build, to exercise the App Store Connect sandbox catalog. TestFlight purchases use the sandbox and do not charge real money.

Record device, iOS version, app build, storefront, product identifier, and observed outcome for:

- Product lookup with the expected localized price.
- Successful purchase and repeat purchase.
- User cancellation, interrupted purchase, and offline retry.
- Ask to Buy/pending approval where available.
- Approval after restarting the app and no duplicate credit.
- Refund/revocation behavior supported by the test environment.

Do not report a payment release as ready until these live-catalog checks pass and the App Store Connect requirements above are confirmed. Never use a real customer's account or charge a real donation as an automated test.
