---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-042
short-slug: notifications
milestone: M5
provenance:
  surfaces:
    - cp:electron/ (notification pattern)
    - kit:rules/dangerous-operations-policy.md (audit-trail of consent-class signals)
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-042-notifications-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-018, F-020]
out-of-scope-notes: |
  Push notifications via remote service (e.g., Firebase) are out of scope for v1.
  Sound + Do-Not-Disturb scheduling per-user is v1.5.
  Per-event notification filtering (e.g., "only halts, not completes") is v1.5.
confidence: high
---

# F-042 — Notifications

## Behavior contract

The desktop emits OS-native notifications (Electron `Notification` API → Windows Action Center / macOS Notification Center / Linux notify-osd) for run lifecycle + governance events:

| Event | Notification |
|---|---|
| Run completes naturally | "Run <id> completed in N cycles" |
| Run halted (per F-018 trigger enum) | "Run <id> halted: <trigger>" with severity styling |
| Kill-switch fired (per F-020) | "Run <id> halted by kill-switch" |
| Cron fire failed | "Schedule <name> fire failed: <reason>" |
| Audit chain verification fail | "AUDIT-CHAIN BREAK on run <id>" — high priority |
| Cost-budget threshold (if F-019 cost is configured with thresholds) | "Run <id> hit X% of estimated cost ceiling" |

Notifications are throttled (max 5/min) + deduplicated within a 30-second window (no spam). Each notification is also persisted to `<state-dir>/desktop/notifications.jsonl` so the operator can review missed alerts. Clicking a notification focuses the desktop window + selects the relevant run in the rail (per F-033). No notification fires when the desktop is the foreground window AND the rail entry for the affected run is already visible.

## Acceptance scenarios

1. **Given** an active cron-spawned run + the operator on a different app, **When** the run halts via kill-switch, **Then** an OS notification fires + clicking it focuses the desktop + the rail selects the halted run.
2. **Given** 10 cron-fire failures within 1 minute, **When** the throttle limit is hit (5/min), **Then** only 5 notifications fire + the remaining 5 are deduplicated/coalesced into a single "5 additional schedule failures" summary notification.
3. **Given** a chain-break notification fires + the operator clicks it, **When** the desktop receives focus, **Then** the affected run is selected + the info panel's chain badge is in red + a banner explains which entry is broken (per F-034 scenario 2).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/desktop/notification-halt.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/desktop/notification-throttle.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/desktop/notification-chain-break.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (desktop window for click-to-focus), F-018 (halt triggers fire notifications), F-020 (kill-switch fires notification)
- **Soft:** F-019 (cost-threshold notifications), F-015 (chain-break notifications), F-023 (cron-fire-failure notifications), F-033 (rail selection on click)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/ | Native notification construction pattern |
| kit:rules/dangerous-operations-policy.md | Audit-trail of high-severity signals (chain break, kill-switch) — operator must see |

## Implementation notes

(empty — populated when implementation begins)
