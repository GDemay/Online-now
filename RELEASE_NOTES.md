# OnlineNow 1.2.0 — prepared candidate changes

Latest intended app source: `d258c6c60886ef181881e27e3f4789c98d88fb2b` in PR #6.
Version 1.2.0 is not live; uploaded build 33 is VALID but older and unattached.

- Reliable connection refresh, foreground lifecycle handling and validated
  provider status, with a diagnostic record for offline Refresh attempts.
- Manual speed tests with clear data-use disclosure and separate TCP/HTTP timings.
- Retain and export the newest 100 checks, with cached summaries, persistence
  recovery and clearer offline/unavailable states.
- Scene-aware StoreKit checkout, optional one-time tips, pending and retry states,
  duplicate-delivery protection and interrupted-purchase recovery.
- Improved large-text history, charts, benchmarks and tip actions; stronger text
  and action contrast; a compact phone landscape header.

Candidate 40 passed both required native Archive/Test actions on exact source
`12f5bfb57b4d13f899f2ae88155f64a93dbaaae3`: **65 passed, seven intentional
live-network skips, zero failures; all five UI cases passed**. Actual local
StoreKit checkout dismissal, repeat tips, Ask-to-Buy and recovery are verified.
Cancellation adds no support credit and does not show a payment failure; earlier
fault injection returned `StoreKitError.unknown`, which remains a visible error.

QA 39 passed four cases on both devices (eight outcomes), with 80 original PNGs.
Detail axes are readable without overlap, although native Charts may omit the
right endpoint label. Palette QA 41 passed on both devices (two outcomes), with
all 24 originals reviewed and all 38 measured contrast samples passing.
**The required final merged-main Archive/Test remains pending.** Only that exact
final main archive will be selected;
older passing/uploaded builds do not establish the latest source is verified.
Account-backed sandbox catalog/purchase readiness and Paid Apps Agreement status
remain UNKNOWN; local StoreKit testing does not establish those account checks.

PR #6 is merged. Its first required main run (42) passed Archive and all five UI
cases, but a local StoreKit fixture-readiness assertion failed: 64 passed,
seven intentional skips and one failure. The test helper is corrected to retain
its first successful receipt observation; production recovery assertions and
application code are unchanged. Build 42 was not selected. A fresh exact-source
required main Archive/Test pass remains the release gate.

Historical **1.2.0 (17)**, source
`86f8f6d60f3f12c181c1b4512f2635f39b201a1e`, was submitted on 22 October 2026 and
rejected under Guideline 2.1(b) for an In-App Purchase issue. Its submission remains
`UNRESOLVED_ISSUES`, the consumable item is `READY_FOR_REVIEW`, and version 1.1
remains public. Build 17's original result was 53 passed, seven intentional skips,
zero failures. No replacement has been attached or resubmitted.

Review submission: `dbdb1c40-2d72-4b31-9cbe-d68d393ccc18`.
See [AUDIT.md](AUDIT.md) for source/run evidence and remaining account checks.
Retain the published privacy branch while App Store metadata references it.
