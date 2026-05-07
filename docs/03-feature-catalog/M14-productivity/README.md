---
artifact-class: milestone-overview
generated-by: hand-authored (wave-006 / lane-a)
status: red
milestone: M14
short-slug: productivity
features: F-101..F-103
authored: 2026-05-06
---

# M14 — Productivity (NEW)

A NEW milestone introduced per Message 11: "Daily briefing + project workspace." Three features turn the engine's audit history into a recurring user-facing artifact: the briefing generator (deterministic summary), the schedule (recurring fire), and the destination (filesystem or clipboard delivery). M14 leverages M2 (cost-ledger F-019), M7 (automations-base F-061), and M9 (WorkIQ adapter F-080) — it is a productivity-layer pillar that depends on the foundational governance + scheduling + M365-integration milestones being complete.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-101 | daily-briefing | Deterministic Markdown summary of past 24h: runs, costs, halts/verdicts, WorkIQ surfaces, open questions; cross-verifiable via cited audit-chain ranges |
| F-102 | briefing-schedule | Recurring schedule (daily / weekdays-only / weekly); fires per-workspace; missed fires emit MISSED_SCHEDULE audit entry |
| F-103 | briefing-destination | Filesystem or clipboard delivery; failed delivery preserves artifact at `runs/<run_id>/briefing.md` per degradation-fallback |

## Dependency DAG

```
M2 (F-019 cost-ledger) ──→ F-101 (cost section data source)
M9 (F-080 workiq-adapter) ──→ F-101 (WorkIQ-surfaces section data source)
M7 (F-061 automations-base) ──→ F-102 (scheduling primitive)

F-101 (briefing) ──→ F-102 (scheduled generator invokes briefing)
                ──→ F-103 (destination dispatches briefing artifact)

F-102 (schedule) ──→ F-103 (scheduled fire invokes destination)

M0 (F-008 storage) ──→ F-103 (run-local artifact preservation on delivery failure)
M2 (F-014 retro)   ──→ F-101 (per-run outcome lines)
M2 (F-015 audit)   ──→ F-101, F-102, F-103 (audit chain records cost source + scheduled fires + delivery outcome)
M8 (F-074 workspace) ──→ F-101, F-102 (briefing scope is per-workspace)
```

## Milestone exit criteria

- All 3 ledgers GREEN
- A daily briefing generated for a fixed time window is byte-equivalent on re-generation (no clock-dependent fields)
- Every briefing number cross-verifies against the cited audit-chain entry range
- A scheduled briefing fires at the configured cadence and dispatches via the configured destination
- Missed schedules emit an audit-chain MISSED_SCHEDULE entry on next engine boot — never silently skipped
- Sub-daily cadence (e.g. every 6h) rejected with `BRIEFING_CADENCE_INVALID` per loop-cadence-discipline
- Failed destination delivery preserves the briefing artifact AND emits BRIEFING_DELIVERY_FAILED audit entry
- Filesystem destination conflict (existing file) does NOT overwrite — explicit BRIEFING_DESTINATION_CONFLICT

## Pending design decisions blocking M14 implementation

- **D-M14-1** — Cron mechanism: F-061 internal scheduler vs OS-level cron (CronCreate analogue). Trade-off is engine-uptime dependence vs OS-coupling. Closure: M14 design wave council-review.
- **D-M14-2** — Briefing template extensibility (fixed sections in v1, user-defined sections post-v1). In-scope decision; documented in F-101 out-of-scope-notes.
- **D-M14-3** — PII-redaction at WorkIQ surfaces section. F-101 v1 emits item IDs only (no body content); deeper redaction wiring deferred to F-017 PII-redaction integration.

## Out of scope (tracked elsewhere)

- Briefing-template customization (user-defined sections) — post-v1 (F-101 out-of-scope-notes)
- Multi-day weekly rollups — post-v1 (F-101 out-of-scope-notes)
- User time-zone / locale personalization — post-v1; v1 defaults to UTC + en-US (F-101 out-of-scope-notes)
- Cross-project briefing aggregation — post-v1; v1 is per-workspace (F-101 out-of-scope-notes)
- Voice-narrated briefing (TTS) — post-v1 (F-101 out-of-scope-notes); related to M13 multimodal input
- Full crontab syntax — post-v1; v1 is enum cadence only (F-102 out-of-scope-notes)
- Multiple schedules per workspace — post-v1 (F-102 out-of-scope-notes)
- Schedule-pause / PTO mode — post-v1 (F-102 out-of-scope-notes)
- Catch-up runs for missed schedules — post-v1; missed are SKIPPED with audit entry (F-102 out-of-scope-notes)
- Email destination — post-v1; needs SMTP/Graph adapter beyond F-080 scope (F-103 out-of-scope-notes)
- Teams-channel destination — F-D-017 deferred catalog (Teams adapter is v1.5)
- Slack/Discord/external-chat destinations — post-v1 (F-103 out-of-scope-notes)
- Encrypted destination payloads (PGP/age) — post-v1 (F-103 out-of-scope-notes)
- Multi-destination fan-out from one schedule fire — post-v1 (F-103 out-of-scope-notes)

## Provenance

`kit:foundational-plan.md M14 NEW Message 11`, `kit:rules/{verification-protocol, no-invented-constraints, loop-cadence-discipline, degradation-fallback-policy, no-silent-deferrals}.md`, `cp:src/services/llm/factory`. Per-ledger `provenance.surfaces`.
