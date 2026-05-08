---
title: Pattern — Scheduled-trigger heartbeat (defeat auto-disable)
status: preview
since: 2026-04-18
last_reviewed: 2026-04-18
promote_by: 2026-07-31
---

# Pattern — Scheduled-trigger heartbeat

Any background task that the runtime auto-disables after a period of inactivity MUST emit a scheduled heartbeat invocation within the inactivity window. No exceptions — silent task expiry is invisible degradation.

**Source:** internal engineering standards docs (build-pipeline + pipeline-permissions guidance) — some internal build systems disable pipelines after 3 months of inactivity; large services defeat this by scheduling Official builds 4× daily (3:00, 9:00, 15:00, 21:00 PST Mon–Fri) and weekly "dogfood" builds. Adopted via **ADOPT-029**.

## The problem

Claude Code's `CronCreate` has a **7-day auto-expire** per the `/loop` skill and `CronCreate` tool contract. A `/council-check` CronCreate task registered with `recurring: true` on day 0 is gone on day 7 without announcement — the channel suddenly stops polling and no member is notified.

Large services hit this at 3 months (some internal build systems); MAD hits it at 7 days (Claude Code CronCreate). Same shape, different interval.

## The pattern

### Two-part defence

1. **Invoke within the window.** Schedule the task to fire at least once inside the inactivity window. For the internal build system, 4×/day gives massive headroom against 3-month expiry. For `CronCreate`, MAD should re-register no later than day 6 of a 7-day window.
2. **Explicit re-registration protocol.** Don't rely on a single `recurring: true` registration to survive the window. Every scheduled-trigger user MUST either:
   - (a) Accept expiry as a feature (e.g., `/loop` iterations that genuinely shouldn't outlive their user context), or
   - (b) Register an explicit re-registration skill that fires at day-6 and re-registers the primary task for another 7 days.

Option (b) is the heartbeat. It's a single-shot CronCreate task scheduled for the 6-day mark, whose prompt is "re-register the main task and schedule the next heartbeat."

### What this looks like in MAD

For `/council-check` polling:

```
Day 0:
  /council-open creates the channel + CronCreate(main) with schedule=*/5 * * * *
  Plus CronCreate(heartbeat) with schedule=0 3 */6 * *  (day 6, 03:00)

Day 6, 03:00:
  Heartbeat task fires. Skill re-registers:
    CronDelete(main) — 0 second grace period
    CronCreate(main) — same schedule, new 7-day clock
    CronCreate(heartbeat) — new 6-day mark
  Emits Context Gap: "main-polling task re-registered; next heartbeat in 6 days."
```

Skills MUST log heartbeat events to `<channel-dir>/heartbeat-log.jsonl` so operators can verify the discipline is working without digging through CronCreate state.

### Status signals

- `council_check.heartbeat_total{outcome}` — counter with `success | failure`. See `metrics/reliability-metrics.md`.
- `council_check.task_expiry_missed_total` — counter that SHOULD be zero; any increment means a heartbeat didn't fire in time and the main task auto-expired.
- Alert threshold: `task_expiry_missed_total > 0` over any 24-hour window ⇒ investigate. The heartbeat is load-bearing for polling-dependent channels.

## When NOT to use this pattern

Some scheduled triggers genuinely shouldn't outlive their trigger window. `/loop` iterations, one-shot reminders, short-term cron tasks tied to a specific investigation — letting these expire is a feature, not a bug.

The pattern applies **only when:**
1. The task is intended to run perpetually (e.g., polling for channel messages).
2. Silent expiry would be a regression (messages stop flowing; operator doesn't notice).
3. The runtime has a fixed inactivity-based auto-disable (CloudBuild 3mo, CronCreate 7d, etc.).

## Related cadences (reference)

| Runtime | Inactivity window | Typical defence |
|---|---|---|
| Some internal build-system pipelines | 3 months | Official build schedule 4×/day Mon-Fri; weekly dogfood build |
| ADO release triggers | n/a | — |
| `CronCreate` (Claude Code) | 7 days | Heartbeat at day-6 re-registers the main task |

## STRIDE implications

- **Denial of Service.** An attacker who suppresses the heartbeat (e.g., deletes the heartbeat CronCreate task) can cause the main task to expire. Mitigation: `council_check.task_expiry_missed_total` is a metric any operator can alert on; add to `operations/quarterly-review.md §Reliability posture`.
- **Tampering.** Heartbeat log is append-only per `rules/concurrency-safety.md`; tampering with it leaves audit evidence.

## Anti-patterns

- **"recurring: true is fine, it just keeps running"** — misreads `recurring` as "forever." It's "until the runtime auto-disables me after the inactivity window." Read the runtime's fine print.
- **Manual re-registration from the operator's session** — only works if someone is watching. The heartbeat must be automated, not a human's reminder.
- **Heartbeat AT the window boundary** — firing at day 7 00:00 is a race with expiry. Always schedule within the window with headroom (day 6, not day 7).

## Related

- `rules/concurrency-safety.md` — atomic writes on heartbeat-log.
- `metrics/reliability-metrics.md` — heartbeat counters.
- `operations/quarterly-review.md` — QSR surfaces missed heartbeats.
- `wiki/patterns/circuit-breakers.md` — complementary failure mode (polling degrades vs. polling disappears).
