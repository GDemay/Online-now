# Online Now audit — 1.2.0 candidate

Audited 20 October 2026 against `e879b12` in `GDemay/Online-now`.
The app is native SwiftUI with SwiftData local history and a StoreKit 2 consumable.
This audit covers the source, project configuration, measurement services, history,
SDK helpers, purchase handling, and release/test setup. It is not a completed device
or App Store audit: no Apple SDK, simulator, device, or App Store Connect session
is available in the execution environment.

## Findings addressed

| Priority | Defect | Resulting behavior |
| --- | --- | --- |
| High | Checks stayed in `.checking` because final state resolution skipped busy states | Completion resolves online, limited, or offline; operations are serialized |
| High | Canceled `NWPathMonitor` was reused; overlapping timers and old tasks survived transitions | Monitor restarts safely; foreground work is canceled and stale results discarded |
| High | Automatic speed downloads consumed data without an explicit action | Only Test Speed downloads a sample; background and path changes run no speed tests |
| High | Estimated warmup inflated reported speed | Throughput uses actual validated bytes divided by elapsed download time |
| High | TCP callbacks and waiting timeouts could resume a continuation twice or hang | Serialized completion, overall deadline, and cancellation finish each probe once |
| High | Empty App Store catalog left a blank tip jar | Visible unavailable message, retry, localized price, loading and purchase states |
| High | Purchase result and transaction updates counted one tip twice | Verified transaction IDs deduplicate delivery and support refund bookkeeping |
| High | Interrupted consumable deliveries were not recovered | Unfinished transactions are processed at startup before being finished |
| Medium | Invalid retry configuration and cancellation could trap or keep work running | Bounded configuration and cooperative whole-operation timeout/cancellation |
| Medium | Redirects and portal pages were treated as internet access | Expected provider HTTPS responses are validated; redirect following is disabled |
| Medium | Captive probe was blocked by iOS transport policy | Narrow exception for `captive.apple.com`; HTTPS remains required elsewhere |
| Medium | Missing measurements produced invented quality values | Quality uses only valid available measurements; otherwise Unknown |
| Medium | Statistics summarized only 20 cached checks; timing fields were not populated | Statistics/export use retained records; TCP and HTTP timings remain separate |
| Medium | History failure crashed startup or was silent | Existing store is preserved; session-only fallback and visible errors allow continued checks |
| Medium | History export, Refresh, and Test Speed lacked usable actions | Accessible actions, CSV file export, clear confirmation, empty/error states |
| Medium | Production screenshot gestures could replace live results with sample values | Simulation and UI fixtures are restricted to Debug builds |
| Medium | Donation UI promised unimplemented benefits and summed currencies as USD | Optional support count and localized storefront prices; every feature stays free |
| Medium | Build script could report success despite failed tests | Real commands and exit statuses are preserved |
| Medium | No shared scheme or app test targets; stale versions/signing generator settings | App/unit/UI targets, shared scheme, catalog resources, aligned app signing identity and version |
| Medium | Required-reason declaration omitted UserDefaults | Manifest declares app-local defaults use; unused disk-capacity declaration removed |
| Low | Small tap targets, fixed text layouts, misleading DNS/VPN/latency labels | Larger accessible controls, adaptive layout, reduced-motion support, accurate measurement labels |

## Verification performed

- Swift 6.0.3 on Linux: the five Foundation transaction-ledger XCTest tests pass.
- Six network service regression tests pass in a scratch Linux harness using the
  service source with `FoundationNetworking` imported and the Apple-only
  `waitsForConnectivity` setter omitted. This is a limited service check, not an
  Apple build. No application source depends on those harness adaptations.
- Swift frontend parsing covers production, example, and test files in Debug
  and Release configurations. Parsing does not typecheck Apple APIs.
- Project references, shared-scheme XML, plist/catalog contents, version/signing
  consistency, shell syntax, and whitespace are checked during preparation.
- Deterministic regression tests were added for lifecycle/history, retries,
  measurement validation, banner behavior, and purchases. App tests include a
  bundled StoreKit catalog. UI tests cover offline refresh/history, large text,
  and two repeatable consumable purchases.
- Live internet tests are opt-in with `ONLINE_NOW_LIVE_NETWORK_TESTS=1`; they
  are unsuitable as deterministic release gates.

## Unverified release requirements

1. Run the committed iOS verification workflow or `scripts/verify_build.sh` on
   a Mac. Inspect test results and screenshots; fix any Apple compiler/runtime
   findings before distributing the candidate.
2. Test airplane mode, Wi-Fi/cellular changes, background/foreground, constrained
   networks, captive portals, and VoiceOver on a device. Deterministic fixtures
   do not validate radio behavior or real portal routing.
3. Validate an existing installation's SwiftData store during upgrade. The schema
   is preserved, and no failed store is deleted, but migration has not run here.
4. In App Store Connect, verify `onlinenow.gdemay` is an approved, available
   consumable for `com.gdemay.onlinenow`; check agreements, banking and tax status.
   No connected App Store Connect tool or signing credential is available here.
5. Complete sandbox/TestFlight purchases, cancellation, delayed approval and
   decline, interrupted delivery, and refund checks. Local StoreKit tests do not
   establish the live catalog or payment-account readiness.
6. Archive/sign with the existing production team, verify version/build against
   App Store Connect, then upload and submit. No signed IPA or App Store release
   was created during this audit.

## Known product boundaries

Download throughput is a short, single-server estimate including setup time.
TCP setup is an RTT estimate, not an ICMP ping or signal-strength measurement.
VPN detection is a tunnel heuristic. Success rate is a percentage of stored
samples, not elapsed uptime. History retains 100 checks. Consumable support
history is local; reinstalling does not restore finished consumables. An Ask to
Buy approval clears pending state through transaction updates; after a decline,
reopen the app to retry because StoreKit emits no consumable transaction update.
