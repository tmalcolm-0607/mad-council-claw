# Pattern: Bounded Iteration Caps

**Canonical name:** Bounded Iteration Caps. Variants: *loop budgets*, *effort budgets*, *iteration limits*, *resource caps*, *spawn caps*.

**One-line definition:** For every loop or resource-creating operation, declare an explicit maximum. The cap is part of the contract; hitting it is treated as a failure mode, not an edge case.

## When to use

- Any retry loop — see `wiki/patterns/per-operation-retry-tables.md` for per-op retries.
- Iterative refinement loops (review → fix → review → fix → ...).
- Resource-creating operations (branches, PRs, work items).
- Token/tool-call budgets per sub-agent (Anthropic's explicit scaling rules).
- Any time "just keep going until done" is the current behavior.

The pattern prevents runaway costs, unbounded recursion, and "mysterious stuck sessions."

## When NOT to use

- Truly unbounded interactive work where a human is in the loop on every step.
- Streaming operations where "N iterations" isn't the right unit.

## Core mechanics

Declare the cap in the skill's frontmatter or runbook. Enforce at runtime. On hit, emit a clear "cap reached" signal — don't silently continue or silently stop.

Three flavors by what's bounded:

### A. Iteration caps (loops)

"Maximum N passes through the loop."

Examples:
- `max 3 review iterations` (adversarial-audit / aegis-reviewer).
- `max 3 content-quality iterations` (agent-native-toolkit/content-quality-loop).
- `max 5 build-fix iterations` (aegis-implementor).
- `max 2 iterative-reanalysis cycles` (review-verdict Phase 4.5).

### B. Consecutive-failure caps (breaker-adjacent)

"Stop after N consecutive failures of the same kind." See `wiki/patterns/circuit-breakers.md`.

Examples:
- `3 consecutive CronCreate polling failures` → disconnect.
- `5 consecutive post-time validation failures` → force-interactive pause.
- `2 consecutive API timeouts on same endpoint` → 15-min pause.

### C. Resource-creation caps

"Don't create more than N of this resource per session."

Examples:
- `max 3 branches + max 3 PRs per session` (zen-agents/programmer).
- `MUST NOT create more than 20 work items without user confirmation` (zen-agents/scrum-master).
- `max 20 outgoing A2A messages per minute per endpoint` (mad.council.a2a.md §10.5).

### D. Tool-call budgets per sub-agent (Anthropic-specific)

"This sub-agent gets at most N tool calls."

Anthropic's explicit scaling rules (from `Building a Multi-Agent Research System`):

| Query complexity | Agents | Tool calls each |
|---|---|---|
| Simple fact-finding | 1 | 3–10 |
| Direct comparison | 2–4 | 10–15 |
| Complex research | 10+ | (clearly divided) |

MAD.Council does not yet declare per-agent tool-call budgets (see CHECKLIST gap #6 — "Per-agent max_tool_calls budget"). Considered a Phase-5 item.

## Pros

- **Prevents runaway cost.** Most failure modes in multi-agent systems are "the agent kept trying." Caps halt the damage.
- **Predictable budgets.** Stakeholders can reason about worst-case token spend.
- **Surfaces errors fast.** Hitting the cap is a signal; silent continuation is not.
- **Forces explicit decisions.** "We'll retry up to 3 times then escalate" is a real design choice; ad hoc retries aren't.
- **Enables automation.** Cap-hit events can trigger paging, escalation, or alternate workflows.
- **Reduces cognitive load.** Maintainers see the cap and understand the bounds without reading code.

## Cons

- **False positives under load.** A flaky-for-30s dependency might trip a cap that a 60s patient retry would have cleared.
- **Picking the right number.** Too low = false halts; too high = runaway. Requires tuning.
- **Cap vs. cap conflicts.** A per-op retry (3) combined with a session resource cap (5) can produce surprising interactions.
- **Requires state tracking.** Counters must survive session restarts or they reset usefully.

## Do / Don't

**Do**:

- **Declare the cap explicitly.** In SKILL.md frontmatter, in the retry table's "On Failure" column, or in `rules/concurrency-safety.md` §Edge cases. Write it down.
- **Pick the cap based on the cost of the operation.** Cheap ops can have higher caps; expensive ops (builds, migrations) get zero-retry.
- **Differentiate caps by severity.** 3-retry on optional dep; 0-retry on build; consent-gate on bulk operation. Don't use one number for everything.
- **Emit a clear "cap reached" signal.** Log the event; emit Context Gap; surface to the user.
- **Track counters at the right scope.** Per-skill-invocation for retries; per-session for resource creation; per-endpoint for breaker counts.
- **Link caps to escalation paths.** 3 build failures → escalate; 20 work items → consent prompt; 100 messages → auto-prompt-to-split.
- **Test the caps.** `evals/` should include scenarios that hit each cap to verify the halt-and-signal behavior.
- **Tune caps over time.** Start conservative; relax if false-halt rate is high; tighten if runaway is observed.

**Don't**:

- **Don't use infinite loops.** Every loop has a cap or a timeout. Full stop.
- **Don't silently continue past the cap.** That defeats the pattern.
- **Don't silently stop at the cap.** The user must know.
- **Don't share one counter across unrelated operations.** Separate counters per dependency.
- **Don't reset caps across retries without intent.** If the first attempt hit the cap and failed, retrying the whole operation doesn't "give you fresh caps."
- **Don't pick arbitrary numbers.** Base caps on marketplace precedent (2 retries for MCP, 3 for polling) or measurable cost.

## Common pitfalls

### Fractional-rate thresholds

"Trip when 30% of the last 100 calls fail." Hard to reason about; hard to debug; hard to test. Prefer consecutive-count ("trip after 3 in a row").

### Counter-scope confusion

A retry counter incrementing across multiple unrelated calls → premature breaker trip. A breaker counter not resetting on success → falsely sticky. Think through scope carefully.

### Cap-as-SLA

"We cap at 3 retries" ≠ "we guarantee 3 retries happen." Users may interpret the cap as a minimum. Documentation should say "at most 3 retries."

### Missing cap on retry-within-retry

Outer loop retries 3 times. Inner loop retries 3 times per outer-iteration. Actual max calls = 9, not 3. Compose caps carefully.

### Infinite-loop in retry exception handler

The retry handler itself has a bug that throws. Now the retry handler retries. Silent infinite loop. Mitigation: the outermost retry handler must be non-retryable.

## Interaction with other patterns

- **+ `wiki/patterns/per-operation-retry-tables.md`** — the retry table declares iteration caps for I/O operations. Same pattern, specific application.
- **+ `wiki/patterns/circuit-breakers.md`** — breakers trip on consecutive-failure caps; the two patterns work together.
- **+ `rules/dangerous-operations-policy.md`** — batch-size gates are caps that trigger consent instead of halt.
- **+ `rules/degradation-fallback-policy.md`** — cap-hit is a Rule-3 Context Gap candidate.
- **+ `wiki/patterns/mode-aware-sizing.md`** — caps may differ per mode (`auto` mode uses tighter caps than `propose`).

## MAD.Council specifics

Summary of caps in `mad.council.a2a.md`:

| Cap | Value | Scope | Where |
|---|---|---|---|
| CronCreate polling failures | 3 consecutive | per-session-per-channel | §10.1 |
| A2A transport failures | 2 consecutive | per-endpoint | §10.1 |
| Post-time validation failures | 5 consecutive | per-session | §10.1 |
| `seq.json` collision retries | 3 | per-post | §10.2 |
| Message file write retries | 2 | per-write | §10.2 |
| `digest.json` read retries | 1 | per-read | §10.2 |
| MAD gate check retries | 1 | per-gate | §10.2 |
| Council role invocation retries | 1 | per-role | §10.2 |
| A2A `tasks/send` retries | 2 (exp backoff) | per-send | §10.2 |
| Alias-reclaim attempts | 5 | per-session | §10.5 |
| Thread message count (soft) | 100 (nudge to split) | per-thread | §7.4 |
| Council re-review iterations | 3 | per-thread | §10.5 |
| Outgoing A2A msgs | 20/min | per-session-per-endpoint | §10.5 |
| Mentions per post | 10 (consent gate) | per-post | §10.4 |

## References

- `mad.council.a2a.md` §10.1, §10.2, §10.4, §10.5 — all MAD caps live here.
- `plugins/ai-native-team/agents/fleet-orchestrator.md` §Stop Conditions — 3-consecutive-failure canonical.
- `plugins/zen-agents/agents/programmer.md` — 3-branches/3-PRs-per-session.
- `plugins/zen-agents/agents/scrum-master.md` — 20-work-items batch gate.
- Anthropic "Building a Multi-Agent Research System" — effort-scaling rules (3-10, 10-15, 10+).
- `rules/concurrency-safety.md` — atomic rename cap (3 retries).
- `wiki/patterns/circuit-breakers.md` — cousin pattern.
- CHECKLIST cross-cutting pattern #5 — bounded iteration caps.
