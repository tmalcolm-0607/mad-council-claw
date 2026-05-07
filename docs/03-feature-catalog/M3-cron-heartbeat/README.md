---
artifact-class: milestone-overview
generated-by: hand-authored (wave-003 / lane-a)
status: red
milestone: M3
short-slug: cron-heartbeat
features: F-023..F-027
authored: 2026-05-07
---

# M3 — Cron / heartbeat / proactive

The proactive plane (`foundational-plan.md` § Architecture). Scheduled, recurring, autonomous run invocations — the substrate for everything that doesn't require interactive prompting (daily briefings, post-deploy verification sweeps, archival sweeps, hourly drift detectors). M3 builds entirely on top of M0 (kernel) and M2 (governance: kill-switch, audit log, cost ledger, retro). Without M3, the engine is reactive only — you have to hand-trigger every run.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-023 | cron-heartbeat | Scheduler reads `automations/cron-schedules.json`; spawns runs on cadence; cadence-profile-aware (no forbidden zone); drift ≤5% over 100-fire window |
| F-024 | skip-on-overlap | Same-schedule overlap → `outcome: "overlap_skipped"`; 0% silent overlaps; cross-schedule overlap allowed |
| F-025 | idle-archival | Closed runs >14 days move atomically to `archive/runs/<YYYY>/<MM>/`; idempotent; orphan-recovery via concurrency-safety |
| F-026 | resume-from-checkpoint | Cycle-boundary `checkpoint.json`; on restart resume from `last_completed_cycle + 1`; integrity verified via F-015 sha256 |
| F-027 | manual-halt-override | `paused: true` per-schedule + `kill-switch.json` halt-run; bulk-pause >5 schedules requires consent |

## Dependency DAG

```
F-001 (kernel) ──→ F-023 (scheduler spawns runs through engine)
F-006 (logger) ──→ F-023 (cron-fires.jsonl is a logger output)
F-008 (storage) ──→ F-023, F-025, F-026 (paths for cron-schedules / archive / checkpoint)

F-023 ──→ F-024 (overlap detection lives inside scheduler)
       └──→ F-025 (archival sweep is itself a cron job)
       └──→ F-026 (scheduler detects + dispatches resume)
       └──→ F-027 (scheduler reads pause state per tick)

F-015 (hash-chain) ──→ F-026 (checkpoint integrity verified via cycle_state_sha256)
F-020 (kill-switch) ──→ F-027 (halt active run path)
F-018 (failure-pattern halt) ──→ F-026 (audit_chain_broken trigger on integrity fail)
F-014 (retro) ──→ F-027 (halted runs fire retro)
F-021 (degradation) ──→ F-025 (filesystem write failures during sweep)
```

## Milestone exit criteria

- All 5 ledgers GREEN
- A registered schedule on `mad-iteration` cadence (270s) drifts ≤14s over a 100-fire window
- A schedule whose run takes 2× the cadence interval produces zero concurrent runs (overlap_skipped count ≥1 in fire log)
- A run aged 14+ days post-close lands under `archive/runs/<YYYY>/<MM>/`
- A run killed mid-cycle resumes from `last_completed_cycle + 1` on scheduler restart
- A registration with `delaySeconds: 600` rejects with `CADENCE_FORBIDDEN_ZONE`
- Manual `kill-switch.json` halts an in-flight cron-spawned run within ≤1 cycle

## Out of scope (tracked elsewhere)

- Skill allowlist + version-pin enforcement at fire time → M7 (F-051..F-056)
- Conditional-trigger automations (event-driven, not cron) → M7 (F-061..F-063)
- Multistep automations (chained cron-fires) → M7 (F-064)
- Compression/cold-storage tiering of archived runs → v1.5 (F-NNN candidate)
- Cross-machine archive/resume (network share) → out of scope for v1
- Cryptographic checkpoint signing → v1.5
- Multi-operator halt quorum → v1.5

## Provenance

`ce:FR-PROACTIVE-001` (heartbeat with overlap detection), `ce:US-7` + `ce:US-8` (heartbeat user stories), `ce:SC-007` (drift ≤5% + 0% silent overlaps), `ce:CronFireRecord` (append-only cron-fires.jsonl shape), `ce:FR-KILL-001` (kill-switch interaction), `kit:loop-skill` (cadence substrate), `kit:rules/{loop-cadence-discipline,resume-protocol,dangerous-operations-policy,concurrency-safety}.md`. Per-ledger `provenance.surfaces`.
