---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-c)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-c
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-090
short-slug: introspection-snapshot
milestone: M11
provenance:
  surfaces:
    - ce:FR-INTROSPECT-001
    - kit:rules/verification-protocol.md
    - kit:council-retro-skill
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
  LOCKED if GREEN AND reviews/F-090-introspection-snapshot-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008, F-014]
out-of-scope-notes: |
  Cross-run calibration drift detection (FR-CALIBRATION-001) is contracted under a
  separate ledger in M11 work-stream (tracked under `out-of-scope-notes` of F-091; will
  land as F-NNN candidate in a subsequent wave). The grader peer-agent (FR-INTROSPECT-002)
  is the F-091 contract — F-090 covers the *self*-introspection emit only.
  UI-side replay-scrubber overlay of introspection signals (D-7 closure) is M12 scope, not M11.
confidence: high
---

# F-090 — Introspection snapshot

## Behavior contract

At every cycle boundary (per F-001) and at run close (per F-014), each active agent emits a structured introspection snapshot to `runs/<run_id>/introspect/<agent_id>/<cycle>.json` capturing self-confidence (1-5 per axis), what-it-is-doing prose (≤500 chars), what-it-believes-blocking prose (≤500 chars), and the SHA-256 of the audit-log range it consumed since the prior snapshot. Snapshots are append-only per agent per cycle (no overwrite). The schema is frozen and shared with F-091 (signal pairs) so the grader can pair self-snapshot vs outcome.

## Acceptance scenarios

1. **Given** an active run with 3 agents past cycle 1 boundary, **When** cycle 2 begins, **Then** `runs/<run_id>/introspect/<agent_id>/1.json` exists for each of the 3 agents with all required fields (`self_confidence`, `doing`, `blocking`, `audit_range_sha256`).
2. **Given** an agent that returned no work in cycle K (idle), **When** the snapshot is emitted, **Then** the snapshot still exists with `doing: "idle"` and `self_confidence` axes set to null (idle is not the same as unscored).
3. **Given** a buggy implementation that omits the snapshot emit for one agent, **When** the cycle transition runs, **Then** the cycle transition rejects with `INTROSPECT_MISSING` naming the agent_id, and the engine retries the snapshot before advancing.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/introspect/cycle-boundary-emit.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/introspect/idle-agent-snapshot.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/introspect/missing-snapshot-rejection.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (cycle boundary triggers emit), F-002 (per-agent identity keys the snapshot path), F-008 (storage layout), F-014 (close triggers final snapshot)
- **Soft:** F-015 (audit-log range SHA references the chained log), F-091 (signal pairs consume snapshots)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-INTROSPECT-001 | Self-introspection via signal pairs (this ledger covers the *self*-emit half) |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — agents must report what they actually did, not what they intended |
| kit:council-retro-skill | 5-axis 1-5 scoring rubric reused at cycle granularity |

## Implementation notes

(empty — populated when implementation begins; consider whether snapshots should also feed F-022 tool-quota observability)
