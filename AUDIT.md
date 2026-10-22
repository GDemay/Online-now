# OnlineNow 1.2.0 audit and release evidence

Updated 22 October 2026. **Version 1.2.0 (17) is waiting for Apple review; it is
not live yet.** Apple accepted the app and its first consumable tip in one review
submission at 16:12:10.53 UTC. Release is configured for after approval; live
version 1.1 remains unchanged.

This audit covers the SwiftUI application, SwiftData history, network services,
StoreKit 2 purchases, accessibility, build configuration, and release metadata.
The submitted binary comes from
`86f8f6d60f3f12c181c1b4512f2635f39b201a1e`. Documentation commits after that
source do not change the binary's identity.

## Findings addressed

| Area | Defect and resulting behavior |
| --- | --- |
| Connection state | Completed checks now leave the busy state and resolve online, limited, or offline. Serialized operations, cancellation, and stale-result protection prevent old checks overwriting the current connection. |
| Lifecycle | A stopped `NWPathMonitor` is recreated. Timers and tasks stop in the background and restart safely in the foreground. Monitoring is foreground-only. |
| Data use and speed | Speed downloads require Test Speed. Throughput uses validated received bytes and the complete measured transfer duration; invalid, incomplete, and portal responses are rejected. |
| Network probes | TCP continuations complete once, with timeout and cancellation. Retries reject invalid configuration and cancel queued or waiting work. Reachability validates expected provider responses without following redirects. The transport exception is limited to `captive.apple.com`. |
| Measurement clarity | TCP setup and HTTP response timings remain separate. Missing measurements produce Unknown quality. Labels describe estimates and possible VPN detection accurately. |
| History | Retention, statistics, and CSV export use the newest 100 checks. Pruning explicitly selects retained records instead of offset-fetching pending inserts. Persistence and separate timing fields have native regression coverage. |
| Storage failures | A failed persistent store is preserved. A session-only fallback and visible errors allow continued checks without silently deleting history. |
| Tip jar | Empty catalog, loading, retry, pending, cancellation, success, and error states are visible. Prices use the current storefront. Every feature stays free; tips grant no promised paid benefits. |
| Purchase delivery | Verified transaction IDs deduplicate purchase results and updates. Startup recovers unfinished consumables; persisted local bookkeeping handles refunds and avoids counting a tip twice. Corrupt ledger data is surfaced. |
| UI and accessibility | Usable Refresh, Test Speed, export, and clear-history actions; confirmation and empty/error states; larger controls, adaptive large text, reduced motion, and accessible labels. Debug fixtures cannot replace production measurements. |
| Build and privacy | Shared app/unit/UI scheme, bundled StoreKit catalog, aligned signing/version settings, accurate command exit statuses, and app-local UserDefaults required-reason declaration. Required Xcode Cloud Test and Archive actions replace the archive post-build test hook. |
| Public information | Source copy fixes placeholder App Store links and misleading VPN, battery, monitoring, and history claims. Corrected listing text and a separately published privacy policy are in App Store metadata; the Pages deployment remains queued. |

## Native verification

Xcode Cloud run `ff7ef6f0-90f0-49c5-8328-6193ca29d7f1` completed both required
actions successfully for the submitted source:

| Check | Verified result |
| --- | --- |
| Native Test | 60 cases: **53 passed, seven intentionally skipped live-network cases, zero failures** |
| Simulator UI | All four passed: offline refresh/history, repeat consumable purchases, actual Ask-to-Buy approval with pending state and relaunch persistence, and large-text navigation |
| StoreKit recovery unit case | One unfinished consumable is recovered and finished, then a repeat purchase is delivered through transaction updates; persisted count is exactly two |
| Archive and distribution export | SUCCEEDED; bundle `com.gdemay.onlinenow`, version 1.2.0, build 17, production team `GB87Z9SKC5`, App Store distribution |
| IPA compatibility | iOS 17 minimum, iPhone/iPad device families, `ITSAppUsesNonExemptEncryption=false` |
| Additional device-layout QA | Test-only run 16 succeeded on iPhone 13 Pro Max and iPad Pro 12.9-inch (6th generation); original native PNGs were reviewed and used for listing updates |

Native investigation also found and fixed a real SwiftData retention defect:
offset fetches could mishandle pending inserts and delete a new check. The
corrected history cases passed in subsequent native runs and in the final suite.

Earlier headless StoreKit purchase tests were moved into the running app's UI,
where purchase presentation and Ask-to-Buy approval passed. In run 15 the first
outside-app consumable purchase succeeded, but a second purchase before finishing
the first was rejected. The final unit fixture follows the recover/finish/repeat
sequence above and passed in run 17. Production purchase-manager logic was not
changed to accommodate the fixture failures.

Supplementary checks passed during preparation: five Linux Foundation
transaction-ledger tests; thirteen retry/measurement cases in a scratch Linux
harness; Debug/Release Swift parsing; project, scheme, plist, catalog, signing,
version, shell, and whitespace checks. The Linux harness used
`FoundationNetworking` and Apple/Combine stand-ins and was not a substitute for
native execution. Live-network cases remain opt-in with
`ONLINE_NOW_LIVE_NETWORK_TESTS=1`.

## Payment and listing corrections

The existing consumable `onlinenow.gdemay` was **MISSING_METADATA**, without
localization, a review screenshot, or an approved consumable version. This was a
confirmed catalog blocker alongside the app's empty-catalog and transaction
handling defects. The en-GB localization, review instructions, and genuine native
tip-jar screenshot are now complete. Existing pricing and 175-territory
availability were preserved.

The first consumable was submitted with the app in the same review submission.
Both now read back **WAITING_FOR_REVIEW**. Local StoreKit success and accepted
submission do not establish a completed live App Store payment.

The listing accurately describes foreground checks, manual data use,
measurement limits, local history, provider requests, and optional tips.
Keywords and required age-rating answers were corrected; existing review
contacts were preserved.

All seven listing screenshots are **COMPLETE**: five iPhone and two iPad images.
The inaccurate iPhone details image was replaced at position two; the other four
iPhone assets and positions were preserved. iPad Home and History use fresh
native captures in that order. Upload checksums, file sizes, and original
1284×2778 / 2048×2732 dimensions matched before the superseded draft assets were
deleted. Live 1.1 assets were independently verified unchanged. The capture's
production `App`/`Sources` files match the submitted app; no images were resized
or edited.

## Delivery record

| Field | Verified value |
| --- | --- |
| App / version resource | `6758242393` / `5d67ab34-1833-4bab-b3c0-016f2f4f51f1` |
| Submitted version/build/source | 1.2.0 (17), `86f8f6d60f3f12c181c1b4512f2635f39b201a1e` |
| Cloud Archive / Test actions | `8746d46c-4939-4b9c-aa07-bcdf9483963c` / `3e637094-7ec3-4674-b667-8879c37a461d`, both SUCCEEDED |
| IPA SHA-256 | `b0f5c308b61f0ac40dd694a030c4482e243c46dff23a99aa1cc679fff82a79ee` |
| Imported and attached build | `a0a6e622-58c5-46d0-987f-69a7fe726308`, build 17, VALID / APP_STORE_ELIGIBLE |
| Consumable version | `aa79aed6-3015-49c8-8cf7-b294dfffaf75` |
| Unified submission | `dbdb1c40-2d72-4b31-9cbe-d68d393ccc18`, accepted 2026-10-22T16:12:10.53Z |
| App and consumable review states | Both WAITING_FOR_REVIEW; 1.2.0 is not published |
| Release policy | AFTER_APPROVAL |

The already-signed IPA was uploaded from Linux through the App Store Connect CLI,
processed, attached, and read back as build 17. Direct App Store submission did
not require TestFlight beta review. Superseded private builds were not attached.

Final pre-submission validation found zero errors and one expected warning:
the first consumable was READY_TO_SUBMIT rather than approved. Strict mode
labels warnings as blocking; review doctor reported zero blockers, and Apple
accepted both intended items together. The public API cannot independently
verify App Privacy questionnaire publication; that informational limitation was
not an Apple submission rejection.

## Privacy page and website follow-up

App Store metadata uses the corrected policy at
[PRIVACY.md](https://github.com/GDemay/Online-now/blob/release/privacy-1.2.0/PRIVACY.md),
published at commit `d6b4d70`. The metadata update and readback were verified.
**Retain branch `release/privacy-1.2.0` indefinitely while App Store metadata
references it.** Verify and update a replacement URL before retiring the branch.

Marketing and support destinations return HTTP 200 over verified TLS. GitHub
Pages still serves old content while scoped rebuild `39804752290` is queued
during GitHub Actions service degradation. Corrected source is committed; the
published privacy fallback avoided depending on that rebuild for submission.
Inspect the queued deployment and verify live copy when the service recovers.

The CLI's optional URL checker disables proxy use and produced request failures
for destinations that independent HTTPS GETs reached successfully. Preserve that
distinction when assessing future URL-check warnings.

## Remaining verification and product boundaries

- Monitor Apple's app and first-consumable review; respond to any review issue.
  Approval and public availability remain separate from accepted submission.
- Physical-device radio transitions, real captive portals, constrained networks,
  VoiceOver on hardware, and an existing installation's SwiftData upgrade were
  not exercised here.
- Verify sandbox/live-storefront catalog and payment behavior, including
  cancellation, delayed approval/decline, interrupted delivery, and refunds.
  Record the environment and storefront; local StoreKit fixtures do not prove
  production payment readiness.
- Speed is a short single-server download estimate including setup time. TCP
  setup is not ICMP ping or signal strength. VPN detection is a tunnel heuristic.
  Success rate describes stored samples rather than elapsed uptime.
- History retains the newest 100 checks. Support history is local and finished
  consumables cannot be restored after reinstalling. After an Ask-to-Buy decline,
  reopen the app to retry because no consumable transaction update is emitted.
