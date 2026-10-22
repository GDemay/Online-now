# Online Now 1.2.0 release runbook

This updates the existing app; do not create another App Store Connect app or change its bundle identifier.

| Item | Expected value |
| --- | --- |
| App Store Connect app ID | `6758242393` |
| Bundle identifier | `com.gdemay.onlinenow` |
| Production developer team | `GB87Z9SKC5` |
| Current published version | `1.1` — recheck before staging |
| Candidate version | `1.2.0` |
| Candidate source branch | `fix/ios-audit-1.2.0`, merged to `main` for the existing automatic workflow |
| Consumable tip product ID | `onlinenow.gdemay` |

Commands below were checked against `asc 5.16.0` help. The CLI's maintained upstream is [rorkai/App-Store-Connect-CLI](https://github.com/rorkai/App-Store-Connect-CLI), which the former `rudrankriyam` repository redirects to. The checksum-verified Linux executable in this workspace is `/workspace/scratch/bin/asc`.

## 1. Configure the smallest sufficient API access

Use an App Store Connect **team API key with the App Manager role** for the existing production account. Supply its Key ID, Issuer ID, and `.p8` private-key file through the environment's credential/file mechanism. The Issuer ID is a UUID; **it is not** developer Team ID `GB87Z9SKC5`.

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

Alternatively, run the read-only preflight using the installed executable:

```bash
ASC_BIN=/workspace/scratch/bin/asc scripts/app_store_preflight.sh
```

It runs only these read operations and prints a bounded summary without credentials. It rejects an unexpected app/bundle and reports missing workflows/product as blockers. It does not establish that a release is ready.

Verify that the returned app is `com.gdemay.onlinenow` in the intended production account. The app response does not expose the signing Team ID: confirm `GB87Z9SKC5` in the existing workflow/signing configuration. Keep the existing consumable ID; do not replace it to work around a missing catalog.

Select the actual workflow ID from the response, then inspect it:

```bash
asc xcode-cloud workflows view --id "$WORKFLOW_ID" --output json
asc xcode-cloud workflows repository --id "$WORKFLOW_ID" --output json
```

The existing `Default` workflow has been observed to trigger for `main`; a candidate branch push alone does not establish that a build started. Merge the prepared candidate with its native test gate into `main`, then identify that exact commit's run. The workflow must use this repository and the shared `OnlineNow` scheme. In Xcode Cloud's workflow settings, verify:

- A Test action runs `OnlineNowTests` and `OnlineNowUITests` on an available iOS simulator, or the repository's post-build test gate executes those tests and fails the build on any failure. Passing only Build or Analyze does not run these tests. Preserve the test gate's `.xcresult` and console summary when tests are invoked by a script instead of a native workflow Test action.
- An Archive action uses Release configuration, the existing production team, and App Store distribution signing.
- Distribution uploads an App Store eligible build to App Store Connect. A build limited to internal TestFlight testing cannot be attached to an App Store release.
- The candidate branch is selectable, and the archive carries version `1.2.0` with an unused build number.

Existing Xcode Cloud signing and archive/distribution actions can build and upload remotely from this Linux workspace. A separate local Mac, signing private key, or manually uploaded IPA is unnecessary for that route. A new pipeline's initial setup or changes to TestFlight post-actions may need the authenticated Xcode Cloud interface; the public workflow API does not expose every web-only option. Confirm those settings before triggering a release build.

## 3. Run the candidate and inspect the results

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

Require actual passing unit, StoreKit, and UI test results from the workflow Test actions or the repository's test gate, plus successful archive/distribution. An empty Test action list is not test evidence. Inspect retained screenshots and `.xcresult` artifacts for failures. `--doctor` mode is useful for diagnosis but can report a failed build with exit code zero; do not use that mode as the release success gate.

The local StoreKit catalog checks accounting and the purchase UI. Before submission, test the real App Store Connect sandbox catalog on a development build with local StoreKit configuration disabled, or in TestFlight, including product lookup, purchase, cancellation, and repeated tips. Follow [TIPPING_SETUP_GUIDE.md](TIPPING_SETUP_GUIDE.md). TestFlight sandbox purchases do not charge real money.

## 4. Stage the processed build and metadata

Get `BUILD_ID` from the selected run's builds response. It is the App Store Connect build resource ID, not the human-readable build number.

```bash
asc builds list --app 6758242393 --platform IOS --version 1.2.0 --processing-state all --paginate --output json
asc release stage --app 6758242393 --version 1.2.0 --platform IOS --build-id "$BUILD_ID" --copy-metadata-from 1.1 --exclude-fields whatsNew --dry-run
```

The public listing reported live version `1.1` on 2026-10-22, released on 2026-02-13 with “We added a donation button.” Confirm the live source version string from step 2 before using `1.1`. Exclude its old `whatsNew` field and set the 1.2.0 release notes below. Require that the exact build belongs to this app, has marketing version `1.2.0`, finished processing as `VALID`, and is eligible for App Store distribution. Then stage:

```bash
asc release stage --app 6758242393 --version 1.2.0 --platform IOS --build-id "$BUILD_ID" --copy-metadata-from 1.1 --exclude-fields whatsNew --confirm
asc versions list --app 6758242393 --platform IOS --version 1.2.0 --output json
```

Staging creates or reuses the version, copies version localization text, attaches the build, and validates public-API readiness. It does not submit. Copying text does not set screenshots, age ratings, category, review details, or pricing; resolve any reported blockers. A staged checkpoint may remain applied when validation fails, so inspect before retrying.

Use the returned version resource ID for `VERSION_ID`. Read its configured locales, then update What's New with the actual release changes for each supported locale:

```bash
asc localizations list --version "$VERSION_ID" --output json
asc localizations update --version "$VERSION_ID" --locale en-US --whats-new "Improved connection checks, manual speed testing, donation handling, accessible controls, and CSV history sharing."
asc validate --app 6758242393 --version 1.2.0 --strict --output json
asc review doctor --app 6758242393 --version 1.2.0 --output json
```

Use the exact locale codes returned by the API; `en-US` is an example only when that localization exists. Check app privacy, regulations/permits declarations, export compliance, review contact details, screenshots, and paid-app agreements in App Store Connect where the public API does not expose a complete check. Only the Account Holder can accept the Paid Applications Agreement; banking/tax prerequisites remain separate from this CLI workflow.

If the donation product needs review, inspect its resource and version IDs:

```bash
asc iap list --app 6758242393 --product-id onlinenow.gdemay --include-versions --paginate --output json
asc iap versions list --iap-id "$IAP_ID" --paginate --output json
```

Require the intended consumable product, completed metadata/pricing/availability, and an approved product or a reviewable IAP version to include with the app. The consumable's product identifier is different from `IAP_ID` and `IAP_VERSION_ID` resource IDs.

## 5. Submit for review, then publish after approval

Reuse an appropriate existing draft submission when one is present, rather than creating duplicate submissions:

```bash
asc review submissions list --app 6758242393 --platform IOS --paginate --output json
```

When a new draft is needed, create it, take `SUBMISSION_ID` from its response, and attach the version:

```bash
asc review submissions-create --app 6758242393 --platform IOS --output json
asc review items-add --submission "$SUBMISSION_ID" --item-type appStoreVersions --item-id "$VERSION_ID" --if-exists skip
```

Only when the consumable has a reviewable IAP version requiring inclusion, also add that exact version:

```bash
asc review items-add --submission "$SUBMISSION_ID" --item-type inAppPurchaseVersions --item-id "$IAP_VERSION_ID" --if-exists skip
```

After release checks pass:

```bash
asc review submissions-submit --id "$SUBMISSION_ID" --confirm
asc submit status --version-id "$VERSION_ID" --output json
```

Submission sends the app to Apple; it does not make the app live. For an approved version set to manual release and in `PENDING_DEVELOPER_RELEASE`:

```bash
asc versions release --version-id "$VERSION_ID" --confirm
asc versions view --version-id "$VERSION_ID" --include-build --include-submission --output json
```

For `AFTER_APPROVAL`, Apple publishes after approval and processing without that manual-release command. Confirm the final version state is `READY_FOR_DISTRIBUTION` (or the older `READY_FOR_SALE` spelling), and verify the public listing shows `1.2.0`. Preserve source SHA, run/build/version/submission IDs, test results, and the actual final status in the release record. Do not label a prepared candidate, uploaded build, or pending review as a published release.

## Sources

- [Apple roles and access](https://developer.apple.com/support/roles/): App Manager, Xcode Cloud, version creation, app/IAP submission, and Account Holder agreements.
- [Apple API keys](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/): team/individual key generation and scope.
- [Apple: start an Xcode Cloud build](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-cibuildruns): official API route used by the CLI.
- [Apple: submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/): review submission requirements.
- [asc 5.16.0 release](https://github.com/rorkai/App-Store-Connect-CLI/releases/tag/5.16.0) and [Xcode Cloud commands](https://github.com/rorkai/App-Store-Connect-CLI/blob/5.16.0/commands/xcode-cloud.mdx).
