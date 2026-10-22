# OnlineNow 1.2.0 (17)

Submitted to Apple on 22 October 2026. The app and first consumable tip are
**WAITING_FOR_REVIEW**; version 1.2.0 is not live yet. Release is configured for
after approval.

- Reliable connection refresh and foreground/background lifecycle handling.
- Manual speed tests with validated throughput and clear data-use disclosure.
- Tip-jar loading/retry states, storefront prices, duplicate-delivery protection,
  and interrupted-purchase recovery.
- Export the newest 100 checks as CSV with separate TCP and HTTP timings.
- Corrected history retention and persistence, accessible controls, large-text
  layouts, status labels, and error messages.
- Completed first-tip metadata and refreshed inaccurate iPhone/iPad screenshots.

Required native Archive and Test actions passed: 53 tests passed, seven live
network tests intentionally skipped, zero failures; all four simulator UI cases
passed. Physical-device and live-store payment verification remain outstanding.

Binary source: `86f8f6d60f3f12c181c1b4512f2635f39b201a1e`.
Review submission: `dbdb1c40-2d72-4b31-9cbe-d68d393ccc18`.
See [AUDIT.md](AUDIT.md) for evidence, payment limitations, and website follow-up.
