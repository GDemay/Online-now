# Visual QA capture fixture provenance

This QA branch runs the app's native SwiftUI views, actual buttons/sheets/navigation,
SwiftData in-memory storage, and StoreKit Test consumable transactions on Apple iOS
simulators. The capture suite exports original PNG screenshot bytes without image
editing, cropping, resizing, compositing, or measurement labels added to the images.

## Deterministic rendering inputs

Explicit `--ui-testing --visual-review` Debug-only hooks supply expected successful,
limited, delayed, or failed network service responses through the app's normal check
pipeline. They do not make external HTTP/TCP measurements and must not be described
as measured network results. The successful speed fixture is 72 Mbps from 27,000,000
bytes over three seconds. `--scenario-checking` delays reachability for twenty
seconds so the busy state can be observed. `--scenario-speed-error` follows a real
button press and finishes with a known service error. Offline uses the app's offline
UI-test snapshot.

`--seed-history` creates six synthetic mixed online/limited/offline check records in
the app's existing isolated in-memory UI-test container. Charts, summary, CSV export,
and clear-history actions operate on those actual SwiftData objects. Fixtures are
not stored in the persistent user database.

`--tip-loading` and `--tip-unavailable` render deterministic StoreKit catalog states;
these two are display fixtures, not evidence of an actual service outage. All other
normal, successful, repeated, pending, approval, cancellation, and failed-purchase
flows use a real `SKTestSession` with the bundled product configuration when the
corresponding test case records that path.

`--temporary-history` / `--history-open-failure` render the app's real existing storage
fallback/error views with synthetic open outcomes; they do not corrupt or remove a
real store. `--tip-prompt` displays the existing frequent-user prompt directly rather
than requiring ten real data-consuming speed tests. `--dark-mode` sets native SwiftUI
preferred color scheme only in explicit visual QA mode.

## Live network observation

`--ui-testing --visual-review --live-network` bypasses deterministic network hooks,
starts the real monitor and service requests, and retains in-memory history. The
smoke test records the simulator's observed network state without requiring the
external internet to be available and without treating a simulator interface as
physical Wi-Fi/cellular evidence. It does not make a real-money purchase.

## Release isolation

Network/storage/tip-catalog fixture logic is guarded by `#if DEBUG` and explicit
UI-test + visual-review launch flags. Additional accessibility identifiers label
existing stat cards and recent activity only. The original visual-review scheme also runs the native unit suite. The follow-up
scheme selects eleven targeted UI cases and skips the already-tested unit suite.
A Debug-only, explicitly flagged error diagnostic exposes only error type/domain/code
through accessibility during review; it never records accounts, URLs, or payloads. No App Store
metadata, pending submission, or production signing configuration is changed by
this QA worktree.
