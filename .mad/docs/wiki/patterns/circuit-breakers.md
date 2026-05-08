# Pattern: Circuit Breakers

**Canonical name:** Circuit Breaker. Variants: *trip breaker*, *consecutive-failure cutoff*, *daemon auto-shutoff*.

**One-line definition:** After N consecutive failures on the same operation or dependency, stop retrying — mark the operation/dependency "open" — and surface the error to the caller. Prevents cascading failures and runaway retry storms.

## When to use

- Operations that can fail transiently (network calls, MCP invocations, external API requests).
- Polling loops that should halt themselves if the poll target is consistently unavailable.
- Automated/daemon-mode agents where a single stuck dependency could burn resources indefinitely.
- Anywhere "keep retrying forever" is the wrong default.

Without a circuit breaker, a transient dependency outage causes:
- Exponential retry backoff consuming tokens/cost.
- Stale state accumulating while the dependency is unreachable.
- Dependent operations piling up waiting.

## When NOT to use

- Single-shot operations where there's no retry to begin with.
- Operations where the caller explicitly wants to wait indefinitely (rare; usually a bug).
- Human-in-the-loop flows where the user is expected to fix the dependency before continuing (manual step replaces the breaker).

## Core mechanics

A circuit breaker has three states:

```
┌──────────┐    N consecutive failures    ┌──────┐
│  CLOSED  │ ────────────────────────────►│ OPEN │
│ (normal) │                               │(halt)│
└──────────┘◄─────────────────────────────└──────┘
       ▲       success on probe after cooldown
       │
       │     probe attempt after cooldown timer
       │           (HALF-OPEN state)
```

- **CLOSED**: normal operation. Every attempt runs; failures increment a counter.
- **OPEN**: halt. No attempts. Existing state preserved. Dependents get an explicit "breaker open" error.
- **HALF-OPEN** (optional): after a cooldown, one probe attempt. Success → CLOSED + counter reset. Failure → OPEN + cooldown extended.

The simplest implementation skips HALF-OPEN and requires manual reset (user action, session restart, explicit retry).

## Common implementations

### Marketplace: plugins/ai-native-team/fleet-orchestrator (canonical)

Explicit 3-failure rule. When a fleet stage fails 3 times consecutively, the orchestrator marks the pipeline "open" and reports. Does not retry the whole pipeline — just surfaces the failure.

- **Pros**: Simple, auditable. Every stage declares its own retry cap, so different stages can have different sensitivities.
- **Cons**: No HALF-OPEN recovery. Requires manual user action to re-enable.

### Marketplace: plugins/zen-agents/programmer

Stricter variant: **zero retry** on expensive operations (`dotnet build`, `dotnet test`). The first failure is the breaker trip. Rationale: retrying a 2-minute build that failed for a real reason wastes 2 minutes. Report and stop.

Also: **max 3 branches / max 3 PRs per session** — a different breaker shape. Not "consecutive failures" but "resource creation caps." Same underlying intent: a runaway session cannot spawn unlimited side effects.

### Marketplace: plugins/sfi-dev-toolkit/sfi-dev-orchestrator

Skill-level breaker: "never retry a failed skill more than once — if it fails twice, escalate." Fits the remediation workflow (you don't want to re-run a migration that failed in weird ways).

### Netflix Hystrix (external reference)

The canonical distributed-systems implementation. Adds:
- Rolling-window failure rate (instead of just consecutive count).
- Separate breakers per downstream dependency.
- Live dashboards for breaker state.
- Forced-open (manual "I know this is broken, don't even try") and forced-closed modes.

Overkill for MAD.Council but worth knowing as the vocabulary source.

### AWS Lambda exponential backoff + dead-letter queue

Adjacent pattern: retry with backoff, then dump to DLQ on exhausting. MAD.Council's "report to Context Gaps + stop" is the DLQ analog — the message isn't processed but isn't lost either.

## Canonical thresholds

| Operation class | Typical consecutive-failure cap |
|---|---|
| Background polling (CronCreate) | **3** (zen-agents / fleet-orchestrator default) |
| A2A transport to a specific endpoint | **2** before pause (then 15-min cooldown) |
| Post-time validation (body cap, mention check, session mismatch) | **5** before force-interactive pause |
| Expensive operations (build, test, migration) | **0** — first failure trips |
| External service calls (MCP, web API) | **2** with exponential backoff |

These aren't dogma — they're reasonable defaults informed by marketplace patterns. Tune per operation.

## Pros

- **Prevents runaway cost**: retry loops on a stuck dependency can burn significant tokens/API-quota. Breakers cap the damage.
- **Surface errors fast**: user learns about a stuck dependency within N failure intervals, not after hours of silent retry.
- **Isolates fault**: one dependency's outage doesn't take down the whole agent session — only the parts that depend on it.
- **Observable**: breaker state is a good metric. Dashboards show which dependencies are flaky.
- **Forces fix-the-root-cause**: a breaker that keeps tripping says "your dependency is broken" louder than a silent retry.

## Cons

- **False trips on transient burst failures**: a flaky-for-30-seconds dependency trips the breaker and then the user has to manually reset even though the dependency recovered.
- **Requires cooldown/reset mechanism**: without HALF-OPEN or manual reset, the user must restart the session to clear.
- **Adds complexity**: a plain retry loop is simpler. Justified only when cost of runaway retry is high.
- **State to persist**: breaker counters must survive session restarts or they reset noise-silently.

## Do / Don't

**Do**:

- **Pick thresholds per operation, not globally.** Background polling can tolerate 3 failures; build-test tolerates 0.
- **Document the threshold in the retry+timeout table** (`mad.council.a2a.md` §10.2 format).
- **Report trips with specific error codes** (e.g., `rc=4` for post failure, not generic "error").
- **Emit Context Gap entries** when a breaker opens (`degradation-fallback-policy.md` Rule 3).
- **Provide a manual reset path**: a `--reset-breakers` flag, a session-restart, or a clear "retry" command.
- **Log trips to an audit file** (`<channel>/breaker-log.jsonl`) for post-hoc analysis.
- **Combine with timeouts**: a breaker without a timeout can hang on one slow-but-succeeding call instead of failing.

**Don't**:

- **Don't retry forever.** The absence of a breaker is a bug.
- **Don't share a breaker across unrelated operations.** Each dependency gets its own counter.
- **Don't use a fractional threshold** ("trip at 30% failure rate") in v1 — too hard to reason about. Use consecutive-count.
- **Don't silent-fail when a breaker opens.** The user must know.
- **Don't auto-reset on session restart alone.** A breaker that opens for a real reason should stay open until the user acknowledges — otherwise the restart itself becomes a cover-up.

## Interaction with other patterns

- **+ `per-operation-retry-tables.md`**: the retry table declares the breaker's threshold. They're complementary: retry+timeout handles the first N failures; breaker handles the N+1.
- **+ `degradation-fallback-policy.md`**: breaker trips are a degradation event → report to Context Gaps.
- **+ `bounded-iteration-caps.md`**: breakers are a form of cap. `max-3-failures` is a cap that trips on failure; `max-100-messages` is a cap that trips on volume.
- **+ `run-id-correlation.md`**: breaker trips inherit the run_id of the failing operation; useful for post-hoc analysis.

## MAD.Council specifics

- **CronCreate polling** (`/council-check` background): 3 consecutive failures → member `status: disconnected` + CronCreate task deleted. User must `/council-join --force-reclaim` to restart polling.
- **A2A transport**: 2 consecutive failures to same endpoint → pause that endpoint for 15 min; messages queue locally with `transport: queued`.
- **Post-time validation**: 5 consecutive validation failures (body cap, mention injection, session mismatch) → force-interactive pause. Alerts user to possible runaway agent behavior.
- **Council review role invocation**: zero-retry on role failures; verdict emits with "2/3 roles completed" note.

All breaker states are logged at `<channel>/breaker-log.jsonl` with `{ts, operation, dependency, trip_count, action, run_id}`.

## References

- `plugins/ai-native-team/agents/fleet-orchestrator.md` §Stop Conditions — 3-failure rule source.
- `plugins/zen-agents/agents/programmer.md` — zero-retry on expensive ops.
- `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md` §Skill Failure — "never retry more than once."
- Netflix Hystrix documentation (archived but instructive) — https://github.com/Netflix/Hystrix/wiki
- Martin Fowler, "Circuit Breaker" — https://martinfowler.com/bliki/CircuitBreaker.html
- `mad.council.a2a.md` §10.1 — spec section.
- CHECKLIST pattern #29 — fleet-orchestrator canonical circuit breaker.
