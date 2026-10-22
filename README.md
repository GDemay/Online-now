# Online Now

An iOS app for checking internet access, measuring a short download sample, and
keeping a local connection history. Built with SwiftUI, Network, SwiftData, and
StoreKit 2. The app requires iOS 17 or later.

The current work prepares **1.2.0 (3)**. It is a release candidate; native iOS and
live App Store purchase verification remain outstanding. See [the audit](AUDIT.md)
and [release notes](RELEASE_NOTES.md).

## Run the iOS app

Open `OnlineNow.xcodeproj` in Xcode, select the shared **OnlineNow** scheme and an
iPhone/iPad simulator, and run. Debug runs use `Configuration.storekit` for local
tips. Disable the scheme's StoreKit configuration when testing the real sandbox
or TestFlight catalog. The app keeps the existing bundle ID
`com.gdemay.onlinenow` and consumable ID `onlinenow.gdemay`.

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

Follow [TIPPING_SETUP_GUIDE.md](TIPPING_SETUP_GUIDE.md) for catalog setup and the
local/sandbox distinction. [AUDIT.md](AUDIT.md) lists the device, storage-upgrade,
payment and signing checks required before distributing this candidate.

## Reusable library

`Package.swift` retains an Apple-platform `OnlineNow` library for the
reachability, retry, measurement, mock, and connectivity-banner components.
The SwiftData application screens are excluded from the library target.
The Linux manifest deliberately exposes only the internal accounting test target.

License: [MIT](LICENSE).
