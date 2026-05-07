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
feature-id: F-092
short-slug: deterministic-replay
milestone: M11
provenance:
  surfaces:
    - ce:FR-REPLAY-001
    - kit:rules/concurrency-safety.md
    - kit:rules/verification-protocol.md
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
  LOCKED if GREEN AND reviews/F-092-deterministic-replay-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008, F-015]
out-of-scope-notes: |
  Outlook / Teams / WorkIQ snapshot capture (FR-OUTLOOK-SNAPSHOT-001 / FR-TEAMS-SNAPSHOT-001 /
  FR-WORKIQ-SNAPSHOT-001) is deferred to v1.5 per canonical-e disposition. Without them,
  M365-touching runs are NOT byte-equivalent on replay — they fall under the 4 enumerated
  exclusions (FR-REPLAY-001 Cat-B Q6: external mutable state, system clock, network jitter,
  M365 surface-state). The replay manifest names which exclusion(s) apply per run.
  Replay UI scrubber (D-7 closure) is M12 scope. Cross-version replay (replay an old run
  on a newer engine version) is post-v1 — v1 requires same-version engine.
confidence: high
---

# F-092 — Deterministic replay

## Behavior contract

Every run produces a **replay manifest** at `runs/<run_id>/replay-manifest.json` listing: frozen-input snapshot SHA-256 (the engine's locked input set at run start), engine semver + commit SHA, the audit log's chain head SHA-256 (per F-015), and the explicit list of `exclusions` (subset of the 4 enumerated: external mutable state, system clock, network jitter, M365 surface-state). The `Replay` operation accepts a manifest + the same engine binary and re-executes the run; outputs MUST be byte-equivalent on every field NOT covered by `exclusions`. Mismatch on a non-excluded field reports `REPLAY_DIVERGENCE` naming the field and the diff.

## Acceptance scenarios

1. **Given** a completed run with `exclusions: []` (pure-deterministic — no M365, no clock-dependent calls, no network), **When** Replay runs against the same engine binary, **Then** every output field byte-matches the original run AND the audit chain head SHA reproduces.
2. **Given** a run with `exclusions: ["m365_surface_state"]` (one Outlook adapter call), **When** Replay runs, **Then** every field outside the M365 adapter's outputs byte-matches; M365-derived fields are reported as `excluded_diff` (not `divergence`).
3. **Given** a run with `exclusions: []` and a buggy engine that introduced non-determinism (e.g. unsorted Map iteration), **When** Replay runs, **Then** Replay returns `REPLAY_DIVERGENCE` naming the first non-matching audit entry index AND the offending field path.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/replay/pure-deterministic-replay.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/replay/excluded-diff-vs-divergence.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/replay/divergence-detection.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine bootstrap freezes input snapshot), F-002 (per-agent identity is part of replay state), F-008 (storage layout — manifest path), F-015 (audit chain head is the determinism anchor)
- **Soft:** F-088/F-089 (soul boundary state is part of frozen input), F-019 (cost ledger byte-matches on pure replay)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-REPLAY-001 | Replay byte-equivalence given frozen input snapshot; 4 enumerated exclusions |
| kit:rules/concurrency-safety.md | Append-only audit log + atomic writes are the storage primitives that make replay possible |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — replay verifies actual past behavior, not claims about it |

## Implementation notes

(empty — populated when implementation begins; M365 snapshot work in v1.5 reduces the exclusion list and tightens replay scope)
