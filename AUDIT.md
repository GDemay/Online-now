# OnlineNow 1.2.0 audit and release evidence

Updated 22 October 2026. **Version 1.2.0 (17) was rejected under Guideline
2.1(b) for an In-App Purchase issue; it is not live.** The unified submission is
`UNRESOLVED_ISSUES`; its app item is `REJECTED` and consumable item is
`READY_FOR_REVIEW`. Apple sent the detailed rejection at 17:49:25 UTC. Live
version 1.1 remains unchanged. Uploaded build 33 is now VALID, but contains an
older palette and remains unattached. Build 17 is still attached to the rejected
version; no replacement attachment or resubmission has occurred.
`AFTER_APPROVAL` remains configured.

This audit covers the SwiftUI application, SwiftData history, network services,
StoreKit 2 purchases, accessibility, build configuration, and release metadata.
The submitted binary comes from
`86f8f6d60f3f12c181c1b4512f2635f39b201a1e`. The prepared replacement source is
`d258c6c60886ef181881e27e3f4789c98d88fb2b` in PR #6. Candidate 40 passed
required Archive/Test actions on earlier source
`12f5bfb57b4d13f899f2ae88155f64a93dbaaae3`. Focused visual run 41 passed on
both devices, with all 24 originals reviewed and all 38 measured contrast samples
passing. The authorized plan is to merge the PR and require the Default
workflow's Archive/Test on the resulting
`main` commit, then inspect and stage only that exact current build. That final
main build has not yet passed or been selected at this checkpoint. None of these
follow-up changes are in submitted build 17.

## Findings addressed

| Area | Defect and resulting behavior |
| --- | --- |
| Connection state | Completed checks now leave the busy state and resolve online, limited, or offline. Serialized operations, cancellation, and stale-result protection prevent old checks overwriting the current connection. |
| Lifecycle | A stopped `NWPathMonitor` is recreated. Timers and tasks stop in the background and restart safely in the foreground. Monitoring is foreground-only. |
| Data use and speed | Speed downloads require Test Speed. Throughput uses validated received bytes and the complete measured transfer duration; invalid, incomplete, and portal responses are rejected. |
| Network probes | TCP continuations complete once, with timeout and cancellation. Retries reject invalid configuration and cancel queued or waiting work. Reachability validates expected provider responses without following redirects. The transport exception is limited to `captive.apple.com`. |
| Measurement clarity | TCP setup and HTTP response timings remain separate. Missing measurements produce Unknown quality. Labels describe estimates and possible VPN detection accurately. |
| History | Retention, statistics, and CSV export use the newest 100 checks. Pruning explicitly selects retained records instead of offset-fetching pending inserts. Follow-up source also records explicit offline Refresh attempts and reads cached statistics without publishing storage errors during SwiftUI rendering. |
| Storage failures | A failed persistent store is preserved. A session-only fallback and visible errors allow continued checks without silently deleting history. |
| Tip jar | Empty catalog, loading, retry, pending, cancellation, success, and error states are visible. Prices use the current storefront. Purchases use the current SwiftUI scene's environment `PurchaseAction` on iOS 17+, retaining the library's iOS 15/macOS 12 fallback. Every feature stays free; tips grant no promised paid benefits. |
| Purchase delivery | Verified transaction IDs deduplicate purchase results and updates. Startup recovers unfinished consumables; persisted local bookkeeping handles refunds and avoids counting a tip twice. Corrupt ledger data is surfaced. |
| UI and accessibility | Usable Refresh, Test Speed, export, and clear-history actions; confirmation and empty/error states; larger controls, reduced motion, and accessible labels. Follow-up source stacks history rows, benchmarks and tip title/price at accessibility sizes, enlarges chart space, reduces axis labels, and makes optional prompts scrollable and modal to accessibility. Debug fixtures cannot replace production measurements. |
| Build and privacy | Shared app/unit/UI scheme, bundled StoreKit catalog, aligned signing/version settings, accurate command exit statuses, and app-local UserDefaults required-reason declaration. Required Xcode Cloud Test and Archive actions replace the archive post-build test hook. |
| Public information | Source copy fixes placeholder App Store links and misleading VPN, battery, monitoring, and history claims. Corrected listing text and a separately published privacy policy are in App Store metadata; the Pages deployment remains queued. |

## Current review issue and follow-up verification

Apple reported: “The In-App Purchase products in the app exhibited one or more
bugs which create a poor user experience.” The review used **iPad Air 11-inch
(M3), iPadOS 27.0.1**, with active internet. The notification did not specify
the purchase failure or provide a screenshot. Apple explicitly states that
unapproved IAP products can work in the review sandbox; lack of approval alone
does not explain this failure.

The review asks for configuration, sandbox, and Paid Apps Agreement checks.
**Paid Apps Agreement status is UNKNOWN:** API-key access works, but no Apple
Account web session is available to verify the Business agreement. No agreement
has been accepted or changed. Current API reads confirm the existing consumable,
complete en-GB localization, 175 available territories including USA, and current
USA $0.99 / France €0.99 pricing; they do not prove a working purchase.

The prepared follow-up source fixes:

- Explicit offline Refresh now saves a diagnostic record and timestamp without
  starting network requests.
- History summary reads use a cache, avoiding fetch/error publication during
  view rendering; summaries still include all retained records.
- Provider badges use the same expected-response and redirect rejection as
  primary reachability. Unreachable internet is described as Unavailable or
  Offline rather than claiming absent radio signal.
- Small-screen and maximum-text layouts adapt history rows, average-speed
  cards, tip actions, benchmarks and charts. Fresh updates say “just now,”
  singular history counts use “check,” and the optional prompt remains usable.
- Later candidate source improves History timestamps and badges, supporting
  text in 25 body/caption locations, primary action contrast, and the compact
  phone landscape header so connection status remains above the fold. History
  supporting-text contrast improved from 3.106:1 to 9.969:1 in run 30. Run 39
  confirms readable, nonoverlapping detail axes and supporting text; native
  Charts may omit the right endpoint label, so both endpoint labels are not
  guaranteed. Run 41 verifies the final status-heading and enabled
  Refresh/retry/prompt color paths: all 38 measured samples passed, with the
  lowest light status-heading ratio 5.978:1 and lowest dark ratio 9.401:1.
- Scene-based purchase presentation uses Apple's recommended SwiftUI environment
  `PurchaseAction` (production change `9f0d613e2544d89a124db077109fbcad389f6b7b`).
  Explicit cancellation, pending and unknown-error responses remain distinct;
  receipt and unfinished-transaction tests cover delivery recovery.

The earlier cancelled-tip assertion was based on an invalid simulator injection.
Native diagnostic run 29 identified **typed `StoreKitError.unknown`**, numeric code
2, for both the requested cancellation fault and unknown-error fault. The SDK did
not deliver a cancellation in that injection; no broad error catch was added to
silence it. The real checkout was present: the earlier runner queried a literal
Cancel label and missed its X control. Actual dismissal using accessibility
identifier `dismiss` passed in Candidate 28 and diagnostic run 29. Run 30 then
verified scene-context checkout dismissal on both phone and iPad: no additional
tip credit, no error and the purchase action available again. Local Ask-to-Buy,
repeat-purchase and failure/retry workflows also passed on both devices.

| Follow-up run | Observed result and limit |
| --- | --- |
| Visual QA 19 | Eleven non-payment UI cases passed on both small iPhone and iPad. Four payment cases failed in the runner helper before purchasing; this was not payment success evidence. Original PNG review exposed maximum-text layout defects and some insufficiently scrolled or unsettled captures. |
| Catalog probe 21, `cc269ad1-b135-41d6-97ea-f311c2914ae4` | Fresh iPad simulator, actual `Product.products` lookup with no local StoreKit session or active configuration reference: zero products initially and after retry, `canMakePayments=true`, storefront unavailable. No purchase attempted. This Debug simulator observation cannot establish account agreements or physical-device sandbox behavior. |
| Candidate 22, `1664d97d-dc25-4a38-b3a7-4cb6bca7dd37` | Historical Archive success; 61 passed, seven skipped, one failed injected-cancellation assertion. The injection was later identified as an unknown error, not an actual cancelled checkout. Source: `cee847ceb7e0c50d56e15ac625e1b06bcfe5da26`. |
| Follow-up QA 23, `0172c6f3-b037-4ad0-b563-c18bcf65ace2` | Nine of eleven UI cases passed on both small iPhone and iPad. Two capture-driver failures prevented full lower-sheet/maximum-text coverage. All 106 PNGs (51 phone, 55 iPad) were reviewed; repeated/misframed section captures were excluded from the reviewed selection. Source: `54580594797301c6be9db1208927ee7848bcd0d1`. |
| Candidate 28, `7fd9bc41-29f4-4967-8e6a-57606f4d79a2` | **COMPLETE / SUCCEEDED at 2026-10-22T21:27:14.098Z.** Required Archive and Test both succeeded on exact source `2f3c1938c1b2ed58e66dda2aad5236b8334ed818`. 72 cases: **65 passed, seven intentional live-network skips, zero failures**. All five iPhone 18 Pro UI cases passed: actual checkout X dismissal without failure or tip credit, repeated tips, Ask-to-Buy approval, offline history, and large-text navigation. 67 unit cases: 60 passed, seven skipped, including three explicit purchase-response cases and receipt/delivery recovery. |
| Payment diagnostics 29, `088dda6e-763b-4640-b27e-dd568d89c466` | Both iPad cases passed, including actual checkout dismissal and failure/retry recovery. Typed diagnostics establish the invalid cancellation injection described above. Isolated source `8d06efa3bcf3eb9eb2a84c437afa28ad1639728c` retains older production code. |
| Visual QA 27, `b875d70c-ec90-41c2-81d9-f38ebca7ad5b` | Source `540558b0be4fa0d4a86c85ee0b0888e4ee27e1b6`; all 101 PNGs reviewed. Medium-sheet capture-driver gaps did not prove missing app rows. The unavailable-product fixture override had been lost and was restored for run 30. Review classifications preserve valid, partial and misframed captures separately. |
| Visual/payment QA 30, `f486cc79-8a9b-47e2-86d2-2f4ba4b517d3` | **COMPLETE / SUCCEEDED** at 21:42:56 UTC: six cases on two devices, 12 successful outcomes and 38 PNGs. Source `a307fba8b1ef5f946e97d954696b6581584f53ef`. Actual scene-context checkout cancellation, Ask-to-Buy, repeat tips and error recovery passed on both devices. Native History supporting-text contrast measured 9.969:1, up from 3.106:1. |
| Candidate 31, `48469560-cc86-43a2-a27a-4de1fe4e34ba` | Required Archive/Test **SUCCEEDED** at 21:47:37 UTC on exact source `f397715fe7c0916a14495e6dce2b1265dc0b789b`; 65 passed, seven intentional live-network skips, zero failures. |
| Candidate 32, `3be6d397-b987-4855-93aa-3fe3e22eb57b` | Required Archive/Test **SUCCEEDED** at 21:49:15 UTC on exact source `611230b7f8295371aab06fa25d8a084b7d1d85d5`; 65 passed, seven intentional live-network skips, zero failures. |
| Final Candidate 33, `3d670e20-7ee0-4e54-9336-d6a602cbb948` | **COMPLETE / SUCCEEDED at 21:53:36 UTC** on exact production source `b8ea6c682e2693b34038ebb276458af2fd13fbe6`. Both required Archive/Test actions succeeded: **65 passed, seven intentional live-network skips, zero failures; all five UI cases passed**. Signed Release IPA 1.2.0 (33), bundle `com.gdemay.onlinenow`, team `GB87Z9SKC5`, iOS 17 minimum, App Store distribution verified. Upload succeeded at 21:58 UTC; the build is VALID but has an older palette and remains unattached. |
| Visual runs 34/35 | Reviewed older-palette captures exposed additional status/action contrast paths. Correctly framed duplicate History captures were omitted only for gallery selection, not treated as missing records. Their results are scoped to earlier source. |
| Semantic QA 37, `28615a11-b846-4ceb-92ee-c19b107d0f87` | Source `954b65c13d9aa191154ab75011c59536690d73bc`; seven cases passed on both devices (14 outcomes), 62 original PNGs reviewed. Native success did not constitute visual approval: raw Home heading and bordered-action contrast paths remained and were corrected in later source. |
| Detail/layout QA 39, `fddb5648-e738-4bc4-8ae1-91a656f3de64` | **COMPLETE / SUCCEEDED** at 22:29:52 UTC on isolated source `d61be7a3ee5ebbd9b06145cd57dd09a6a61407c3`: four cases on both devices, eight successful outcomes, 80 original PNGs. Axes are readable and do not overlap; native Charts omits the right endpoint in some captures. No claim that both endpoint labels render. |
| Candidate 40, `8e1ad725-bd74-478f-bd16-172a318d2a68` | Required Archive/Test **COMPLETE / SUCCEEDED** at 22:20:25 UTC on exact source `12f5bfb57b4d13f899f2ae88155f64a93dbaaae3`: **65 passed, seven intentional live-network skips, zero failures; all five UI cases passed**, including native local checkout dismissal, repeat tips and Ask-to-Buy. This local archive was not uploaded. |
| Focused palette QA 41, `e84f816b-e918-4af1-af22-666aaa0bd43a` | **COMPLETE / SUCCEEDED** at 22:33:09 UTC. Isolated source `a1d1cdcb0e812184d44c8cb73e2ccd9b9d494545` matches latest production Release source `d258c6c60886ef181881e27e3f4789c98d88fb2b`. One case on both devices passed (two outcomes); all 24 original PNGs reviewed, no new layout defect observed. All 38 measured contrast samples passed across light/dark status headings, Refresh, retry, optional prompt and primary actions. |


Build 33 is uploaded and VALID but remains staging evidence for an older palette;
it must not be substituted for the final `main` build. No replacement has been
attached or resubmitted. Actual App Store account/catalog/purchase behavior and
Paid Apps Agreement status remain UNKNOWN; no Account Holder confirmation has
been received. Verify those account-backed checks and the final main build before
treating the rejection as resolved. Local StoreKit success alone does not prove
Apple's review environment works.


## Historical verification of submitted build 17

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
localization or a review screenshot. Completing those fields made it ready for
submission; prior IAP approval is not required to function in Apple's review
sandbox. The en-GB localization, review instructions, and genuine native tip-jar
screenshot are complete. Existing pricing and 175-territory availability were
preserved.

The first consumable was submitted with the app in the same review submission.
Apple subsequently rejected the app for the IAP issue described above; the
consumable review item remains `READY_FOR_REVIEW`, not approved. Local StoreKit
success and accepted submission do not establish a completed live App Store
payment.

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

## Historical delivery record — build 17

| Field | Verified value |
| --- | --- |
| App / version resource | `6758242393` / `5d67ab34-1833-4bab-b3c0-016f2f4f51f1` |
| Submitted version/build/source | 1.2.0 (17), `86f8f6d60f3f12c181c1b4512f2635f39b201a1e` |
| Cloud Archive / Test actions | `8746d46c-4939-4b9c-aa07-bcdf9483963c` / `3e637094-7ec3-4674-b667-8879c37a461d`, both SUCCEEDED |
| IPA SHA-256 | `b0f5c308b61f0ac40dd694a030c4482e243c46dff23a99aa1cc679fff82a79ee` |
| Imported and attached build | `a0a6e622-58c5-46d0-987f-69a7fe726308`, build 17, VALID / APP_STORE_ELIGIBLE |
| Consumable version | `aa79aed6-3015-49c8-8cf7-b294dfffaf75` |
| Unified submission | `dbdb1c40-2d72-4b31-9cbe-d68d393ccc18`, accepted 2026-10-22T16:12:10.53Z |
| Current review states | Submission UNRESOLVED_ISSUES; app REJECTED; consumable review item READY_FOR_REVIEW; 1.2.0 is not published |
| Release policy | AFTER_APPROVAL |

The already-signed IPA was uploaded from Linux through the App Store Connect CLI,
processed, attached, and read back as build 17. Direct App Store submission did
not require TestFlight beta review. Superseded private builds were not attached.

Historical pre-submission validation found zero errors and one expected warning:
the first consumable was READY_TO_SUBMIT rather than approved. Strict mode
labels warnings as blocking; review doctor reported zero blockers, and Apple
accepted both intended items together. That admission did not establish payment
readiness; the later review rejection is the current release blocker. The public API cannot independently
verify App Privacy questionnaire publication; that informational limitation was
not an Apple submission rejection.

## Privacy page and website follow-up

App Store metadata uses the corrected policy at
[PRIVACY.md](https://github.com/GDemay/Online-now/blob/release/privacy-1.2.0/PRIVACY.md),
published at commit `d6b4d70`. The metadata update and readback were verified.
**Retain branch `release/privacy-1.2.0` indefinitely while App Store metadata
references it.** Verify and update a replacement URL before retiring the branch.

Marketing and support destinations return HTTP 200 over verified TLS, but the
public Pages site still serves old placeholder content. Rebuild `39804752290`
remains queued at this checkpoint. Corrected source is committed; the public
GitHub privacy fallback remains the metadata destination. Verify the deployed
copy before treating HTTP 200 as evidence of current content or retiring any
publisher/privacy branch.

The CLI's optional URL checker disables proxy use and produced request failures
for destinations that independent HTTPS GETs reached successfully. Preserve that
distinction when assessing future URL-check warnings.

## Remaining verification and product boundaries

- Resolve the 2.1(b) IAP rejection. Candidate 40, local payment workflows and
  focused palette QA 41 pass; the required final `main` Archive/Test remains
  pending. Build 33 is VALID but older and unattached. Account-backed sandbox
  catalog/purchase behavior and Paid Apps Agreement status remain UNKNOWN.
  Approval and public availability remain separate from native test success,
  upload and accepted submission.
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
