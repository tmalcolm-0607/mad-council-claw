---
artifact-class: milestone-overview
generated-by: hand-authored (wave-002 / lane-b)
status: red
milestone: M2
short-slug: governance-triad
features: F-014..F-022
authored: 2026-05-07
---

# M2 — Governance triad

The governance plane (`foundational-plan.md` § Architecture). Identity + policy + audit + halt + cost. Together with M1 (backend) and M0 (kernel), this is the load-bearing core: a run that completes WITHOUT M2 features active is not a real run — it has no provenance, no halt path, no cost record, no privacy guard.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-014 | pre-close-retro-signal | Mandatory retro on every close; 5-axis 1-5 + what-worked/hard; halted runs include trigger_evidence_sha256 |
| F-015 | hash-chained-audit-log | Every audit entry: prev_sha256 + entry_sha256; tamper detection via `Verify-AuditChain` |
| F-016 | query-audit-log | Streaming filter API: by run/agent/event/time; surfaces chain-broken warning before yielding |
| F-017 | pii-redaction-egress | Outbound emissions reject literal paths/aliases/secrets/IPs; never silently strip |
| F-018 | failure-pattern-halt | 9-trigger enum; auto-halt on consecutive_failures / overplanning / spawn-storm / etc. |
| F-019 | cost-ledger | Per-agent cost-ledger.ndjson; exact integer-token sums; NO default budget enforcement |
| F-020 | kill-switch | Read-time-propagating `kill-switch.json`; mid-run halt within next cycle |
| F-021 | degradation-fallback | 5 rules + circuit-breaker (3-fail-in-window); Context Gaps emission |
| F-022 | tool-quota | Per-cycle / per-run / max-active quotas per agent; rejection logged to audit |

## Dependency DAG

```
M0 (F-001 kernel, F-002 identity, F-006 logger, F-008 storage) ──→ all M2 features

F-015 (hash-chain) ──→ F-016 (query)
                  └──→ F-014 (retro audit-stamps)
                  └──→ F-018 (trigger_evidence_sha256)
                  └──→ F-020 (kill-switch trigger evidence)

F-014 (retro)  ──→ F-018 (halt fires retro with evidence)
              └──→ F-020 (kill-switch fires retro)

F-002 (identity) ──→ F-019 (cost ledger keyed on agent_id)
                └──→ F-022 (quotas per agent_id)

F-013 (M1 events) ──→ F-019 (usage events feed ledger)

F-001 cycle hook ──→ F-020 (read-time kill-switch check)
                └──→ F-021 (cycle-scoped degradation tracking)
                └──→ F-022 (cycle-scoped quota counters)

F-018 (halt) and F-021 (degradation) share anomaly-thresholds.md.
F-018 escalates F-021 required-dep failures into halts.
```

## Milestone exit criteria

- All 9 ledgers GREEN
- A natural-close run produces a valid retro with all 5 axes
- A halted run (any of the 9 triggers) produces retro with `halted_by: <trigger>` + valid `trigger_evidence_sha256`
- `Verify-AuditChain` returns valid for any complete run
- `kill-switch.json` set mid-run halts within ≤1 cycle
- Cost ledger sums match expected per the recorded-fixture tests
- An outbound emission containing `sk-ant-api03-...` rejects with `PII_DETECTED`
- A 4th tool call after `max_calls_per_cycle: 3` rejects with `QUOTA_EXCEEDED`

## Out of scope (tracked elsewhere)

- Manual operator verdict at `verdicts/manual-<ts>.json` (FR-OVERRIDE-001) — deferred to M11 introspect/replay
- Cryptographic spawn signing / Entra principal binding (FR-IDENTITY-002/003) — v1.5
- Ingress redaction (FR-PRIVACY-002) — v1.5
- Skill allowlist + version-pinning (FR-GOV-001/002) — M7
- Per-workspace tool-cap policy default = 10 (F-125 NEW frontier-research candidate)

## Provenance

`ce:FR-CORE-004/005`, `ce:FR-AUDIT-001/002`, `ce:FR-AUDIT-PRIVACY-001`, `ce:FR-KILL-001`, `kit:rules/{anomaly-thresholds, degradation-fallback-policy, mcp-tiering, no-invented-constraints, concurrency-safety}.md`. Per-ledger `provenance.surfaces`.
