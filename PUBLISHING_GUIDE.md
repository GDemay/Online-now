# Online Now 1.2.0 release runbook

This updates the existing app; do not create another App Store Connect app or change its bundle identifier.

**Current status, 22 October 2026:** Apple accepted submission `dbdb1c40-2d72-4b31-9cbe-d68d393ccc18` at `2026-10-22T16:12:10.53Z`. App version 1.2.0 and its first consumable are both `WAITING_FOR_REVIEW`, with release policy `AFTER_APPROVAL`. **1.2.0 is not live.** Monitor this submission; do not upload, stage, or submit it again. Mutation examples below apply only to a future editable candidate.

| Item | Expected value |
| --- | --- |
| App Store Connect app ID | `6758242393` |
| Bundle identifier | `com.gdemay.onlinenow` |
| Production developer team | `GB87Z9SKC5` |
| Current published version | `1.1` — 1.2.0 is awaiting review |
| Submitted version/build | `1.2.0` / `17` |
| Verified binary source | `86f8f6d60f3f12c181c1b4512f2635f39b201a1e` |
| Consumable tip product ID | `onlinenow.gdemay` |

Commands below were checked against `asc 5.16.0` help. The CLI's maintained upstream is [rorkai/App-Store-Connect-CLI](https://github.com/rorkai/App-Store-Connect-CLI), which the former `rudrankriyam` repository redirects to. Install a verified executable and put `asc` on `PATH`; a workspace-specific executable or wrapper path is not required.

## 1. Configure the smallest sufficient API access

Use an App Store Connect **team API key with the App Manager role** for the existing production account. Supply its Key ID, Issuer ID, and `.p8` private-key file through the environment's credential/file mechanism. The Issuer ID is a UUID; **it is not** developer Team ID `GB87Z9SKC5`.

This release successfully authenticated using the user-provided App Store Connect API key and issuer through a private wrapper outside the repository. Reuse the securely configured authentication route; no Apple ID password is needed for these API operations.

App Manager can use Xcode Cloud, create versions, manage app metadata, and submit the app and its in-app purchase for review. Developer alone cannot complete this release: Apple's role table gives it read-only Xcode Cloud access and no app-version creation or app submission. Admin is unnecessary for an already configured signing/build pipeline. A team key covers all the account's apps and cannot be limited to only this app.

An individual key is an alternative when its user has App Manager access to this app. It uses `ASC_KEY_TYPE=individual`, Key ID, and `.p8`, with no Issuer ID; it cannot use provisioning endpoints. Prefer the team-key route here if certificate/profile work might be needed.

The CLI accepts these environment bindings; let the credential mechanism populate their values:

```text
ASC_KEY_TYPE=team
ASC_KEY_ID=<Key ID>
ASC_ISSUER_ID=<Issuer UUID>
ASC_PRIVATE_KEY_PATH=<absolute path to the securely mounted .p8>
ASC_STRICT_AUTH=true
ASC_TELEMETRY_DISABLED=1
DO_NOT_TRACK=1
```

The private-key file must be readable only by its owner (`0600`). Do not print it, put it in command substitutions, commit it, use `asc auth token` in logs, or enable API debug logging during release work. Keep any config or key outside the repository. A complete environment credential set with no selected `ASC_PROFILE` skips stored credentials. If using a stored profile instead, explicitly select that profile rather than mixing credentials from different accounts.

An Account Holder or Admin can generate the team key in [Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api). Initial API access and legal agreements require the Account Holder. A new API key does not accept agreements, repair banking/tax information, or prove the donation product is approved.

## 2. Inspect the existing app and pipeline without changing them

With `asc` on `PATH` and authentication configured:

```bash
asc version
asc api GET /v1/apps/6758242393
asc versions list --app 6758242393 --platform IOS --paginate --output json
asc xcode-cloud workflows list --app 6758242393 --paginate --output json
asc iap list --app 6758242393 --product-id onlinenow.gdemay --include-versions --paginate --output json
asc builds list --app 6758242393 --platform IOS --version 1.2.0 --processing-state all --paginate --output json
```

Alternatively, run the read-only preflight, setting `ASC_BIN` only if the authenticated executable is not on `PATH`:

```bash
scripts/app_store_preflight.sh
```

It runs only these read operations and prints a bounded summary without credentials. It rejects an unexpected app/bundle and reports missing workflows/product as blockers. It does not establish that a release is ready.

Verify that the returned app is `com.gdemay.onlinenow` in the intended production account. The app response does not expose the signing Team ID: confirm `GB87Z9SKC5` in the existing workflow/signing configuration. Keep the existing consumable ID; do not replace it to work around a missing catalog.

Select the actual workflow ID from the response, then inspect it:

```bash
asc xcode-cloud workflows view --id "$WORKFLOW_ID" --output json
asc xcode-cloud workflows repository --id "$WORKFLOW_ID" --output json
```

The existing `Default` workflow has been observed to trigger for `main`; a candidate branch push alone does not establish that a build started. Merge the prepared candidate into `main`, then identify that exact commit's run. The workflow must use this repository and the shared `OnlineNow` scheme. In Xcode Cloud's workflow settings, verify:

- The required `Test - iOS` action runs `OnlineNowTests` and `OnlineNowUITests` on the configured iPhone simulator. Passing only Archive or Analyze does not run these tests. Native Test actions retain results and screenshots; the old archive post-build test script was removed after the Test action was configured.
- An Archive action uses Release configuration, the existing production team, and App Store distribution signing.
- Distribution uploads an App Store eligible build to App Store Connect. A build limited to internal TestFlight testing cannot be attached to an App Store release.
- The candidate branch is selectable, and the archive carries version `1.2.0` with an unused build number.

Existing Xcode Cloud signing and Archive actions build and sign remotely. If Cloud does not import the exported App Store IPA automatically, `asc builds upload` can upload that signed IPA from Linux; this route was verified for build 17. A local Mac is not needed to upload an already signed artifact. A new pipeline's initial setup or changes to TestFlight post-actions may need the authenticated Xcode Cloud interface; the public workflow API does not expose every web-only option.

## 3. Run the candidate and inspect the results

Build 17 passed its required native Xcode Cloud Archive and Test actions: **53 passed, seven intentionally skipped live-network tests, zero failures; all four UI tests passed**. These results apply to source `86f8f6d60f3f12c181c1b4512f2635f39b201a1e`. Preserve that SHA when recording later documentation changes.

The existing push-triggered workflow can run after the candidate is merged to `main`, without an API key. If an explicit run is needed after authentication, identify the configured workflow ID and the merged source commit first:

```bash
asc xcode-cloud run --workflow-id "$WORKFLOW_ID" --branch main --wait --poll-interval 30s --timeout 1h --output json
```

Use the returned build-run ID for `RUN_ID`. Record the source commit SHA and compare it with the intended candidate; do not select a similarly named earlier build.

```bash
asc xcode-cloud status --run-id "$RUN_ID" --output json
asc xcode-cloud actions list --run-id "$RUN_ID" --paginate --output json
asc xcode-cloud artifacts list --run-id "$RUN_ID" --paginate --output json
asc xcode-cloud build-runs builds --run-id "$RUN_ID" --paginate --output json
```

For each Test action ID from the actions response:

```bash
asc xcode-cloud test-results list --action-id "$TEST_ACTION_ID" --paginate --output json
```

Require actual passing unit, StoreKit, and UI test results from the required workflow Test action, plus successful archive/distribution. An empty Test action list is not test evidence. Inspect retained screenshots and `.xcresult` artifacts for failures. `--doctor` mode is useful for diagnosis but can report a failed build with exit code zero; do not use that mode as the release success gate.

The local StoreKit catalog checks accounting and the purchase UI; it does not prove live catalog or payment-account readiness. Separately test the real App Store Connect sandbox catalog on a development build with local StoreKit configuration disabled, or in TestFlight, including product lookup, purchase, cancellation, and repeated tips. Follow [TIPPING_SETUP_GUIDE.md](TIPPING_SETUP_GUIDE.md). TestFlight sandbox purchases do not charge real money. **TestFlight beta review is not required to submit directly for App Store review.** Record physical-device and live-store limitations separately from the passing simulator tests.

## 4. Stage the processed build and metadata

Version 1.2.0 build 17 is already uploaded, processed, attached, and submitted. Inspect its existing resources without restaging them:

```bash
asc builds list --app 6758242393 --platform IOS --version 1.2.0 --processing-state all --paginate --output json
asc versions view --version-id 5d67ab34-1833-4bab-b3c0-016f2f4f51f1 --include-build --include-submission --output json
```

For a future candidate, identify the exact run's signed App Store IPA and source SHA first. If it has no imported build, upload once, then use the returned `BUILD_ID`; it is a resource ID, not the human-readable build number:

```bash
asc builds upload --app 6758242393 --ipa "$SIGNED_APP_STORE_IPA" --platform IOS --wait --poll-interval 30s --output json
asc builds info --build-id "$BUILD_ID" --output json
asc builds pre-release-version view --build-id "$BUILD_ID" --output json
```

Require the expected app, marketing version, build number, `VALID` processing state, and App Store eligibility. Create or reuse the future editable version and attach that exact build. Copying metadata does not establish screenshot, age-rating, review-detail, privacy, or pricing readiness. A staged checkpoint may remain applied when validation fails, so inspect before retrying.

Use the future version's resource ID for `NEXT_VERSION_ID`, inspect its actual locales, and write release notes for that version. The current primary locale is `en-GB`:

```bash
asc versions attach-build --version-id "$NEXT_VERSION_ID" --build-id "$BUILD_ID" --wait --output json
asc localizations list --version "$NEXT_VERSION_ID" --output json
asc localizations update --version "$NEXT_VERSION_ID" --locale en-GB --whats-new "$RELEASE_NOTES"
asc validate --app 6758242393 --version-id "$NEXT_VERSION_ID" --ipa "$SIGNED_APP_STORE_IPA" --strict --output json
asc review doctor --app 6758242393 --version-id "$NEXT_VERSION_ID" --output json
```

Use only locale codes returned by the API. Check app privacy, regulations/permits declarations, export compliance, review contact details, screenshots, and paid-app agreements in App Store Connect where the public API does not expose a complete check. Only the Account Holder can accept the Paid Applications Agreement; banking/tax prerequisites remain separate from this CLI workflow.

**Privacy URL retention:** the current App Store `privacyPolicyUrl` is [PRIVACY.md on `release/privacy-1.2.0`](https://github.com/GDemay/Online-now/blob/release/privacy-1.2.0/PRIVACY.md), published at commit `d6b4d70`. **Retain branch `release/privacy-1.2.0` indefinitely while this metadata URL uses it.** Verify a replacement is public and update App Store metadata before retiring the branch. GitHub Pages source has been corrected, but deployment run `39804752290` is queued during Actions degradation; the fallback privacy page is already public and must remain available.

If the donation product needs review, inspect its resource and version IDs:

```bash
asc iap list --app 6758242393 --product-id onlinenow.gdemay --include-versions --paginate --output json
asc iap versions list --iap-id "$IAP_ID" --paginate --output json
```

Require the intended consumable product and completed metadata/pricing/availability. Its first version must be included with a new app version in the **same unified review submission**. The consumable's product identifier is different from `IAP_ID` and `IAP_VERSION_ID` resource IDs.

## 5. Submit for review, then publish after approval

For the current release, monitor the already accepted unified submission:

```bash
asc submit status --id dbdb1c40-2d72-4b31-9cbe-d68d393ccc18 --output json
asc review status --app 6758242393 --version 1.2.0 --output json
```

For a future editable candidate, first list submissions and reuse an appropriate existing draft. Create one only when needed, take `NEW_SUBMISSION_ID` from its response, and add the future app version:

```bash
asc review submissions-list --app 6758242393 --platform IOS --paginate --output json
asc review submissions-create --app 6758242393 --platform IOS --output json
asc review items-add --submission "$NEW_SUBMISSION_ID" --item-type appStoreVersions --item-id "$NEXT_VERSION_ID" --if-exists skip
```

The first consumable must be added to that same submission before submitting either item. Later IAP versions requiring review can also be included. Use the IAP **version** resource ID, not the product ID:

```bash
asc review items-add --submission "$NEW_SUBMISSION_ID" --item-type inAppPurchaseVersions --item-id "$IAP_VERSION_ID" --if-exists skip
asc review items-list --submission "$NEW_SUBMISSION_ID" --include appStoreVersion,inAppPurchaseVersion --paginate --output json
```

For that future submission only, after release checks pass and all intended items are present:

```bash
asc review submissions-submit --id "$NEW_SUBMISSION_ID" --confirm
asc submit status --id "$NEW_SUBMISSION_ID" --output json
```

Submission sends the app to Apple; it does not make the app live. For an approved version set to manual release and in `PENDING_DEVELOPER_RELEASE`:

```bash
asc versions release --version-id "$APPROVED_VERSION_ID" --confirm
asc versions view --version-id "$APPROVED_VERSION_ID" --include-build --include-submission --output json
```

For `AFTER_APPROVAL`, Apple publishes after approval and processing without that manual-release command. Confirm the final version state is `READY_FOR_DISTRIBUTION` (or the older `READY_FOR_SALE` spelling), and verify the public listing shows `1.2.0`. Preserve source SHA, run/build/version/submission IDs, test results, and the actual final status in the release record. Do not label a prepared candidate, uploaded build, or pending review as a published release.

## Sources

- [Apple roles and access](https://developer.apple.com/support/roles/): App Manager, Xcode Cloud, version creation, app/IAP submission, and Account Holder agreements.
- [Apple API keys](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/): team/individual key generation and scope.
- [Apple: start an Xcode Cloud build](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-cibuildruns): official API route used by the CLI.
- [Apple: submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/): review submission requirements.
- [Apple: submit an In-App Purchase](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/): first consumable and app version must share one submission.
- [Apple: invite external testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/): TestFlight App Review applies to external beta distribution.
- [asc 5.16.0 release](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.16.0) and [Xcode Cloud commands](https://github.com/rorkai/App-Store-Connect-CLI/blob/5.16.0/commands/xcode-cloud.mdx).
