---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-113
short-slug: telemetry-opt-in
milestone: M16
provenance:
  surfaces:
    - cp:src/main/settings
    - cp:src/features/settings/SettingsScreen.tsx
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/single-owner-accountability.md
    - kit:rules/no-silent-deferrals.md
    - foundational-plan.md D-1 (default off / local-only / remote)
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
  LOCKED if GREEN AND reviews/F-113-telemetry-opt-in-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-067]
out-of-scope-notes: |
  Per-signal opt-in granularity (e.g. "metrics on, traces off") is OUT for v1;
  v1 is a single global tri-state (off / local-only / remote). Per-tenant /
  per-channel opt-in is OUT (M2-governance owns channel-level concerns).
  Remote-export endpoint configuration UI is part of M8 settings (F-067) — F-113
  defines the contract and ships local-only as default; remote endpoint URL +
  auth pickup is M8 wiring. v1.5 considers per-signal granularity.
confidence: high
---

# F-113 — Telemetry opt-in (off / local-only / remote)

## Behavior contract

The engine MUST gate telemetry emission and export through a single tri-state setting `telemetry.mode ∈ {off, local-only, remote}` persisted via M8 settings (F-067). Default per foundational-plan D-1 is `local-only` — signals are written to F-110's JSONL sink with no network egress. `off` disables ALL signal emission (logs/metrics/traces/crashes still capture for crash forensics per F-111 but are NOT written to disk; in-memory ring buffer only, dropped on next launch). `remote` enables export to a user-configured OTel collector or compatible endpoint; this is a Dangerous Operation per `rules/dangerous-operations-policy.md` and MUST require explicit user consent through M8 settings UI with a preview of what will be sent. Mode changes take effect immediately at the engine's next cycle boundary; no engine restart required. Mode transitions are themselves audited per F-015 (governance-triad audit-log) — every change records `from_mode`, `to_mode`, `actor.session_id` (per F-002), `timestamp_utc`, satisfying single-owner-accountability. There is NO default-to-remote path under any condition; the engine MUST NOT silently upgrade from local-only to remote (per `rules/no-silent-deferrals.md`).

## Acceptance scenarios

1. **Given** a fresh install with no settings overrides, **When** the engine boots and emits its first signals, **Then** `telemetry.mode` resolves to `local-only`, signals land in `<userData>/telemetry/otel-{date}.jsonl`, and a network-block test assertion confirms zero outbound HTTP/HTTPS connections from the telemetry subsystem.
2. **Given** a user changes telemetry mode from `local-only` to `remote` via M8 settings, **When** the change is committed, **Then** the consent prompt shows a preview of signal types that will be exported, the engine awaits explicit "yes", an audit-log entry records the transition with the user's session_id, and the next emitted signal is sent to the configured OTel endpoint (verified via test-time OTel collector).
3. **Given** mode is set to `off`, **When** the engine emits 50 signals over a 30-second run, **Then** the JSONL sink file does NOT exist (or contains zero new lines), the in-memory ring buffer holds the last N signals for crash forensics only, and on graceful shutdown the buffer is dropped with no persistence.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/telemetry/default-local-only-mode.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/telemetry/remote-mode-consent-and-audit.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/telemetry/off-mode-no-disk-writes.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel; mode read on every cycle), F-008 (storage; settings persistence path), F-067 (M8 settings; UI surface for the tri-state)
- **Soft:** F-110 (sink listens to mode), F-111 (crash reporting respects off mode for disk writes), F-112 (metrics respect off mode), F-015 (audit-log records mode transitions), F-002 (session_id stamps the actor on transitions)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/main/settings | clawpilot settings persistence pattern; engine adopts and extends |
| cp:src/features/settings/SettingsScreen.tsx | clawpilot settings UI shape for the mode picker control |
| kit:rules/dangerous-operations-policy.md | remote-mode transition is a Dangerous Operation; explicit consent + preview required |
| kit:rules/single-owner-accountability.md | mode transitions stamp the actor's session_id in the audit log |
| kit:rules/no-silent-deferrals.md | engine MUST NOT silently upgrade modes; default-to-remote is forbidden |
| foundational-plan.md D-1 | tri-state contract: off / local-only (default) / remote |

## Implementation notes

(empty — populated when implementation begins)
