---
title: Rule — Loop cadence discipline
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — Loop cadence discipline

`/loop` dynamic-mode and any kit-defined recurring-poll mechanism MUST pick `delaySeconds` from one of two named profiles. The 280-1199s zone is FORBIDDEN — it pays the cache-miss cost without amortizing.

**Source:** Phase 3 (B/C) wall-clock attribution and the warm-cache analysis in `.mad/reports/phase3-time-analysis.md`. The Anthropic prompt cache TTL is 5 minutes (300 seconds). Cadence below 300s keeps the cache warm; cadence at 1200s+ amortizes the cache miss across enough useful work; cadence between 280s-1199s is "worst-of-both" — pay the miss without amortizing.

## The two profiles

| Profile | `delaySeconds` | When to use | Cache behavior |
|---|---:|---|---|
| **`mad-iteration`** | **270** | MAD development/planning loops where each iteration completes in ~3-6 min and produces meaningful work (audit findings, MAD pipeline steps, council reviews). The cadence keeps the next wake within the warm cache window with margin under the 300s TTL. | Warm. Re-reading conversation = ~10% of input tokens. |
| **`deployment-watch`** | **1500** | Long-poll loops where each iteration is a quick check (~10-30s) but you're waiting for slow external state change (deployment finishes, build completes, file appears). Amortizes the cache-miss cost across enough waiting time that per-iter cost is acceptable. | One cache miss per long sleep. |

## Forbidden zone

```
0s ──── 270s ──── 300s ──── 1200s ──── 3600s
        │           │            │
        │           └ "worst-of-both" wall ─ DO NOT PARK HERE
        │
        └ Warm-cache zone        └ Amortized-cache-miss zone
```

`delaySeconds` in the range **280-1199s** burns the prompt-cache (>300s TTL exit) without amortizing the cost across enough waiting time. NEVER pick this zone. If you're tempted to "wait 5 minutes" or "check every 10 minutes":

- **Need fast iteration?** Drop to 270s (warm cache).
- **Genuinely waiting on slow state change?** Commit to 1200s+ (one cache miss buys longer wait).
- **600s/900s "feels right"?** It's the worst pick — re-evaluate which problem you're actually solving.

## How to apply

Per-cron-create / per-ScheduleWakeup invocation, declare the profile in the `reason` field:

```typescript
ScheduleWakeup({ delaySeconds: 270, reason: "profile=mad-iteration; checking next loop step", ... })
ScheduleWakeup({ delaySeconds: 1500, reason: "profile=deployment-watch; waiting for build", ... })
```

If the situation doesn't fit either profile (e.g., active polling for a quickly-changing log line), pick within the warm-cache zone (60-270s) and document the rationale. Do NOT silently pick a value in the forbidden zone.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| `delaySeconds: 600` "to check every 10 minutes" | Worst-of-both zone — pays cache miss with no amortization | 270s (warm) or 1500s (amortized) |
| `delaySeconds: 300` "to stay just at the cache TTL" | Right at the boundary; race-prone; effectively a cache miss | 270s with margin |
| Picking cadence by "what feels intuitive" without checking the zones | Rounded-to-minutes intuition lands in the forbidden zone | Read `phase3-time-analysis.md` § Speed pathologies before picking |
| Different cadence per task with no documented profile | Cognitive load; can't audit which loops are healthy | Use named profiles (`mad-iteration`, `deployment-watch`) consistently |

## Personal override

Individual operators may legitimately pick a non-default cadence within the warm-cache or amortized zones based on workload. Examples that fit:

- 120s (mad-iteration variant): very-active polling where iter wall-clock is sub-1-minute
- 1800s (deployment-watch variant): low-frequency background watch
- 240s (mad-iteration variant): extra cache margin

Examples that do NOT fit:

- 600s "as a default" — forbidden zone
- 900s "to balance cost and speed" — forbidden zone

## Related

- `.claude/skills/loop/SKILL.md` (bundled) — the `/loop` skill body's dynamic-mode wakeup logic
- `.mad/reports/phase3-time-analysis.md` — empirical wall-clock attribution that motivates this rule
- `CLAUDE.md` § Skill-invocation timing metrics — operator-facing summary of speed pathologies
- `.claude/rules/autonomous-loop-discipline.md` — the loop continues per stop-conditions, not per cadence
