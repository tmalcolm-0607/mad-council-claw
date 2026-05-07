---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-066
short-slug: automations-results-in-shell
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/ipc/automations-desktop-ipc.ts
    - cp:src/features/automations/AutomationListView.tsx
    - cp:electron/automations/manager.ts
    - kit:rules/dangerous-operations-policy.md
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
  LOCKED if GREEN AND reviews/F-066-automations-results-in-shell-review.md exists with verdict: ACCEPT.
depends-on: [F-061, F-065, F-032, F-042]
out-of-scope-notes: |
  Multistep chain orchestration is F-064; persistence is F-065.
  Per-automation permissions also surface here (the AutomationCapabilities.perAutomationPermissions flag from clawpilot is wired here so a run's permission overrides flow through the desktop shell IPC alongside the result).
  Heartbeat-on-demand per automation (AutomationCapabilities.heartbeatRunNow) surfaces here as a "Run Now" button + result delivery.
  CLI-side surfacing of automation results (headless mode) is F-029 + this feature's same IPC contract.
  Notification-style result alerts go through F-042 (M5 notifications).
  GitHub-import of automations (`GithubImportView.tsx`) is bundled here as a reference to the import path; the import itself is OUT OF SCOPE for v1 (deferred).
configurable: |
  Result body size cap: 64 KB per run-result-event; over-cap output is truncated with a tail-pointer to the full log file.
  Per-automation permission overrides scoped via the F-058/F-059 rule scope `per-automation`.
confidence: high
---

# F-066 — Automations results in shell

## Behavior contract

When an automation finishes (success, failure, or cancellation), the manager (F-061) emits a `RUN_COMPLETED` event over the IPC contract carrying `{ run_id, automation_id, status, started_utc, finished_utc, summary, output_truncated_at_bytes? }`. The desktop shell (F-032) renders the result inline in the AutomationListView with a status icon (succeeded / failed / partial / cancelled), an expandable details pane (full step-by-step output), and a `Re-run` button. Failures additionally fire an OS-native notification (F-042) with the failed step name + first 200 chars of error. Per-automation permission overrides flow through the same IPC pipe: each step's `permission_decisions: [{ kind, target, tier, matched_rule_id }]` are embedded in the result so an operator can audit what authority the automation exercised. Per-automation perms (`AutomationCapabilities.perAutomationPermissions` from clawpilot) attach as `scope: "per-automation"` rules on F-059.

## Acceptance scenarios

1. **Given** an automation completes successfully, **When** the desktop receives `RUN_COMPLETED`, **Then** the AutomationListView entry shows a green status icon AND clicking it expands to show each step's output AND a `Re-run` button is available.
2. **Given** an automation fails on step 3 of 5, **When** the result is rendered, **Then** the entry shows a red status, the failed step name, AND an OS-native notification fires per F-042 with the truncated error.
3. **Given** an automation's run includes 5 step decisions of mixed `ALLOW`/`ASK`/`DENY`, **When** the result is delivered, **Then** the `permission_decisions` array contains 5 entries with each step's tier + matched_rule_id, AND each entry's audit row exists in F-060 keyed by the same matched_rule_id.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/automations/result-rendered-in-shell.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/automations/result-failure-notification.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/automations/result-permission-decisions-attached.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-061 (manager fires the result event), F-065 (persistence holds the result history this UI reads), F-032 (desktop shell window receives + renders), F-042 (notification on failure)
- **Soft:** F-058 + F-059 (per-automation perm overrides ride alongside the result), F-060 (audit row cross-referenced by matched_rule_id), F-029 (CLI surfaces the same event)
- **Independent:** F-051..F-057 (skills as step targets but not direct dependency)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "shell-visible" is item 16 (final) of the M7 catalog list |
| cp:electron/ipc/automations-desktop-ipc.ts | Desktop-specific IPC channel for run-completed events |
| cp:src/features/automations/AutomationListView.tsx | UI surface that renders results inline |
| cp:electron/automations/manager.ts | Origin of the RUN_COMPLETED event |
| kit:rules/dangerous-operations-policy.md | Per-run permission_decisions array makes consent gates auditable per-automation |

## Implementation notes

(empty — populated when implementation begins)
