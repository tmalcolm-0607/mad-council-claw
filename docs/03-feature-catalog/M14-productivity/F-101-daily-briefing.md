---
artifact-class: feature-ledger
generated-by: hand-authored (wave-006 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-006 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-101
short-slug: daily-briefing
milestone: M14
provenance:
  surfaces:
    - kit:foundational-plan.md M14 NEW Message 11
    - kit:rules/verification-protocol.md
    - kit:rules/no-invented-constraints.md
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
  LOCKED if GREEN AND reviews/F-101-daily-briefing-review.md exists with verdict: ACCEPT.
depends-on: [F-019, F-080]
out-of-scope-notes: |
  Briefing-template customization (user-defined sections beyond the v1 set) is post-v1.
  Multi-day rollups (weekly briefings) are post-v1 — v1 is a single-day briefing only.
  Briefing personalization based on user's working hours / time-zone / locale is post-v1
  (defaults to UTC + en-US in v1). Cross-project briefing aggregation (one briefing
  spanning multiple F-074 workspaces) is post-v1 — v1 emits one briefing per workspace.
  Voice-narrated briefing (TTS) is post-v1 — v1 is text only.
confidence: high
---

# F-101 — Daily briefing

## Behavior contract

The engine generates a **daily briefing document** summarizing the past 24 hours of activity for the active F-074 project workspace. The briefing is a structured Markdown artifact with fixed sections: (a) **Runs completed** (count + per-run one-line outcome from F-014 retros); (b) **Costs** (total $ from F-019 cost-ledger entries in window); (c) **Halts/verdicts** (count + types per F-018/F-020); (d) **WorkIQ surfaces touched** (Teams/Outlook/email items per F-080 adapter, names only — no PII bodies); (e) **Open questions** (collected from runs that emitted AskUserQuestion-style prompts). Generation is deterministic given a fixed time window — running it twice for the same `[start, end]` produces byte-equivalent output. The briefing carries the source `audit-chain.jsonl` ranges it summarized so any number can be cross-verified per `rules/verification-protocol.md`.

## Acceptance scenarios

1. **Given** the past 24 hours had 5 completed runs (3 ACCEPT, 2 HALT), $4.27 in costs, and 12 WorkIQ items touched, **When** the briefing generator runs, **Then** the output Markdown contains exactly: `Runs: 5 (3 ACCEPT, 2 HALT)`, `Total cost: $4.27`, and a `WorkIQ surfaces: 12 items` section listing item IDs (no body content).
2. **Given** the briefing generator runs at 09:00 UTC for window `[Yesterday 09:00 UTC, Today 09:00 UTC]`, **When** it runs again at 09:05 UTC for the SAME window, **Then** the output is byte-equivalent (same SHA-256) — no clock-dependent fields and no invented values per `rules/no-invented-constraints.md`.
3. **Given** the briefing claims `Total cost: $4.27`, **When** a verifier sums F-019 cost-ledger entries from the cited audit-chain range, **Then** the sum matches $4.27 exactly — the briefing's footer cites `audit-chain entries [N..M]` so the assertion is verifiable.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/briefing/briefing-section-shape.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/briefing/briefing-deterministic-byte-equiv.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/briefing/briefing-cost-cross-verifiable.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-019 (cost-ledger is the cost section's data source), F-080 (WorkIQ adapter is the surfaces-touched section's data source)
- **Soft:** F-014 (retros provide per-run outcome lines), F-015 (audit-chain is the verifier's source-of-truth), F-018 (halt entries), F-020 (verdict entries), F-074 (project workspace scopes the briefing)
- **Independent:** F-061 (automation base — not strictly required for v1 manual briefing, becomes hard for F-102 scheduled briefing)

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M14 NEW Message 11 | "Daily briefing + project workspace" verbatim from user's NEW-features answer |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — every number cites its audit-chain range so it's cross-verifiable |
| kit:rules/no-invented-constraints.md | Briefing reports actual costs/counts from real entries; no estimated/invented values |

## Implementation notes

(empty — populated when implementation begins; PII redaction at WorkIQ surfaces section deferred to F-017 PII-redaction wiring)
