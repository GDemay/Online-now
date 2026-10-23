# Online Now

An iOS app for checking internet access, measuring a short download sample, and
keeping a local connection history. Built with SwiftUI, Network, SwiftData, and
StoreKit 2. The app requires iOS 17 or later.

This branch prepares an **optional-tip 1.2.1 follow-up** authorized by the owner.
It restores the Support developer button without automatic tip prompts. The
submitted free-only 1.2.0 (45) remains Waiting for Review; public version 1.1
remains live at this source checkpoint. Real account-backed payment readiness
is still unverified. Exact native results and submission state are recorded in [the audit](AUDIT.md),
[release notes](RELEASE_NOTES.md), and the release checkpoint.

## Run the iOS app

Open `OnlineNow.xcodeproj` in Xcode, select the shared **OnlineNow** scheme and an
iPhone/iPad simulator, and run. This candidate offers optional tips through the
Support developer button, with no automatic prompts. Local checkout regressions
use `Configuration.storekit`. The disabled-purchases SDK UI fixture requires
`--ui-testing --purchases-disabled-ui-fixture` in Debug; these arguments cannot
change Release behavior. Production donation release requires account-backed
sandbox checks with the local catalog disabled. The
existing bundle ID `com.gdemay.onlinenow` and consumable ID `onlinenow.gdemay`
are preserved.

The home screen provides Refresh and Test Speed. Speed tests run only on request,
use up to 10 MB of sample data per completed test, and show a single-server
estimate. Monitoring pauses while the app is inactive. History retains 100
checks and can be exported as CSV. All features work without tipping.

## Verify

The existing Xcode Cloud Default workflow archives `main` and runs the required
`Test - iOS` action for app, StoreKit, and UI tests. Results are available through
App Store Connect. The optional `iOS verification` GitHub Actions workflow also
checks the Swift package when Actions is enabled. To run locally on a Mac:

```sh
xcrun simctl list devices available
ONLINE_NOW_DESTINATION='platform=iOS Simulator,id=<UUID>' ./scripts/verify_build.sh
```

Live network tests are opt-in with `ONLINE_NOW_LIVE_NETWORK_TESTS=1`. Regular
checks use deterministic fixtures. Debug UI tests pass `--ui-testing --offline`
to use an in-memory history and offline network fixture. These flags have no
effect in Release builds.

On Linux, `swift test` verifies only the Foundation transaction ledger. It does
not build or test the iOS app, StoreKit, SwiftData, or SwiftUI. Apple platform
services and the reusable SDK must be tested with Apple's SDKs.

## Payments and release

The submitted 1.2.0 update defers donation purchases. This separate candidate
restores them after verification; existing local support bookkeeping remains.
Paid Apps Agreement status and actual account-backed payment readiness remain
unverified, so this branch is not a production payment-readiness claim.
[TIPPING_SETUP_GUIDE.md](TIPPING_SETUP_GUIDE.md) covers those prerequisites for a
later donation-enabled release. [PUBLISHING_GUIDE.md](PUBLISHING_GUIDE.md) and
[AUDIT.md](AUDIT.md) describe the current exact-source release gates and the
remaining physical-device/storage-upgrade limits.

## Reusable library

`Package.swift` retains an Apple-platform `OnlineNow` library for the
reachability, retry, measurement, mock, and connectivity-banner components.
The SwiftData application screens are excluded from the library target.
The Linux manifest deliberately exposes only the internal accounting test target.

License: [MIT](LICENSE).
