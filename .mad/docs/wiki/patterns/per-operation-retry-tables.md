# Pattern: Per-Operation Retry + Timeout Tables

**Canonical name:** Retry Table. Variants: *operational limits table*, *timeout contract*, *per-op policy table*.

**One-line definition:** For every operation a skill performs, declare in a 4-column table: Operation · Max Retries · Timeout · On Failure. The table is the contract; runtime behavior matches it exactly.

## When to use

- Skills with any external dependency that can fail (MCP, HTTP, filesystem, subprocess).
- Any skill that might loop on failure — declared caps prevent runaway.
- Any time you've written a loose "retry if it fails" in code without a cap.

Without a retry table, failures silently multiply costs and confuse users. With one, behavior is predictable and auditable.

## When NOT to use

- Pure computation — no I/O means no retry needed.
- One-shot scripts where an unhandled failure is acceptable (just print the error and exit).

## Core mechanics

Four columns. Not three. Not five.

| Operation | Max Retries | Timeout | On Failure |
|---|---|---|---|

**Column discipline:**

1. **Operation** — human-readable name. Specific enough to find in logs.
2. **Max Retries** — integer. `0` means "no retries" (first failure is terminal). `N` means "try up to N+1 times total."
3. **Timeout** — duration. Per-attempt, not total.
4. **On Failure** — what happens after retries exhausted. Must be actionable: "Report Context Gap; use cached value" is good; "Fail" is not.

## Canonical examples

### From `plugins/zen-agents/agents/scrum-master.md`

```markdown
| Operation | Max Retries | Timeout | On Failure |
|-----------|-------------|---------|------------|
| `extract-docx-text.ps1` | 1 | 30s | Cannot proceed; report error |
| ADO MCP: get work item | 2 | 15s | Report error; ask user for manual input |
| ADO MCP: create work item | 2 | 30s | Report error; output JSON for manual creation |
| ADO MCP: add child link | 2 | 15s | Report error; note unlinked items in summary |
| WorkIQ-style org-context queries | 1 | 10s | Skip org context; note in Completion Report |
| Vendor docs MCP search (e.g., Microsoft Learn, AWS Docs) | 1 | 10s | Skip docs validation; proceed without |
| `collect-repo-context.ps1` | 1 | 60s | Skip repo context; note in Completion Report |
```

### From `plugins/zen-agents/agents/programmer.md`

```markdown
| Operation | Max Retries | Timeout | On Failure |
|-----------|-------------|---------|------------|
| ADO MCP work item fetch | 2 | 15s | Report error; ask user for manual input |
| ADO MCP branch/PR creation | 2 | 30s | Report error; suggest `az` CLI fallback |
| Vendor docs MCP queries (e.g., Microsoft Learn) | 1 | 10s | Skip; proceed without docs validation |
| WorkIQ queries | 1 | 10s | Skip; note unavailability in report |
| Build validation (`dotnet build`) | 0 | 120s | Report build errors; do NOT auto-retry |
| Test execution (`dotnet test`) | 0 | 180s | Report test failures; do NOT auto-retry |
```

Note the **zero-retry** on `dotnet build` and `dotnet test` — expensive operations don't benefit from automatic retry. One failure = stop + report.

### From `mad.council.a2a.md` §10.2

MAD.Council's canonical table:

```markdown
| Operation | Max Retries | Timeout | On Failure |
|-----------|-------------|---------|------------|
| `digest.json` read | 1 | 5s | Report Context Gap; use last-known digest if any; continue |
| `seq.json` read-increment-write | 3 (retry with next number on collision) | 2s | Fail post with `rc=4`; do not leave seq.json in inconsistent state |
| Message file write | 2 | 10s | Fail post with `rc=4`; message is not delivered |
| `channel.json` member update | 2 | 10s | Preserve session; warn in next `/council-check` |
| `/council-check` invocation (via CronCreate) | 0 | 30s | See circuit breaker rules |
| A2A `tasks/send` | 2 with exponential backoff | 20s first try, 40s second | Queue message locally with `transport: queued` |
| MAD gate check | 1 | 15s | Fail the gate with clear error; do not fabricate success |
| Council role invocation (Advocate/Skeptic/Architect) | 1 | 60s per role | Skip that role in the verdict; note "N/3 roles completed" |
```

## Pros

- **Auditable contract.** Anyone can review the table and know exactly how the skill behaves under failure.
- **No ad-hoc retries.** Rule is "match the table, don't invent" — reduces runtime bugs.
- **Cost predictable.** Max-retries × timeout per operation → bounded worst-case cost.
- **Failure modes explicit.** "On Failure" column is a deliberate design decision, not emergent behavior.
- **Documentation by construction.** The table IS the operational runbook.
- **Circuit breaker threshold derivation.** Consecutive-failure counts read naturally from the table.

## Cons

- **Table staleness.** As operations evolve, the table can drift. Need maintenance discipline.
- **Not all operations fit.** Some async streaming operations (SSE) don't map to retry+timeout. Document separately.
- **Scope discipline needed.** One skill ≠ one table. A skill with 15 operations should probably be decomposed.
- **Tempting to generalize.** "One table for all MCP calls" loses operation-specific nuance. Prefer explicit entries.

## Do / Don't

**Do**:

- **One row per distinct operation.** Don't merge "all ADO MCP calls" into one row; individual calls have different failure semantics.
- **Zero-retry on expensive ops** (builds, tests, migrations). Automatic retry burns time.
- **2-retry default for transient ops** (MCP calls, HTTP). First might be flaky; two is enough.
- **1-retry for optional context sources.** If the dep is optional, one quick retry and move on.
- **Timeout per-attempt, not total.** `15s` means each attempt; total with retries is `15s × (1+retries)`.
- **"Do NOT auto-retry" explicit** on expensive ops. Reviewer sees it's intentional.
- **Use the "Report X Gap" language** in On Failure — ties into `degradation-fallback-policy.md` Rule 3.
- **Exponential backoff for network calls.** "20s first try, 40s second" is better than "20s × 2."
- **Match rates with `wiki/patterns/circuit-breakers.md`.** If the table says 3 retries and the breaker trips at 2, they conflict.

**Don't**:

- **Don't skip operations because they "obviously work."** They don't.
- **Don't invent retries at runtime.** If the skill's behavior requires more retry, update the table.
- **Don't use infinite retries.** That's not retry, that's "pray."
- **Don't retry idempotent-only operations non-idempotently.** POSTing `/council-post` twice creates two messages. Either the operation is idempotent, or retries apply only to pre-commit phases.
- **Don't mix retry+timeout with circuit breaker in one cell.** Keep the table clean; circuit breaker is a separate rules file.
- **Don't log retries silently.** Every retry attempt is a Context-Gap candidate; surface if appropriate.

## Common pitfalls

### The "retry the whole workflow" anti-pattern

Skill fails mid-way. Retry from the top. Skill re-does already-done work, possibly creating duplicates.

Mitigation: retries apply to individual operations with defined idempotency. Workflow-level retry is a different pattern (and usually a bug).

### Timeout-inside-timeout

Skill timeout is 30s. Called operation timeout is 60s. Skill-level timeout fires while the operation is still running, leaves the operation in an unknown state.

Mitigation: operation timeouts ≤ their calling context's remaining budget. Coordinate end-to-end.

### "Retry on any error" vs "retry on transient errors"

Retrying a 401 Unauthorized accomplishes nothing. Retrying a 503 Service Unavailable often helps. Distinguish.

Mitigation: classify errors in the On Failure column. "Retry on 5xx; fail on 4xx" is an acceptable shorthand.

### Table drift

Skill is updated; table isn't. Now docs and behavior disagree.

Mitigation: PR review step — every skill change reviews the table as part of the diff.

## Interaction with other patterns

- **+ `rules/degradation-fallback-policy.md`** — the On Failure column implements Rule 3 (report Context Gap) and Rule 4 (respect retry limits).
- **+ `wiki/patterns/circuit-breakers.md`** — the breaker threshold is typically `max_retries + 1` in the table.
- **+ `rules/verification-protocol.md`** Rule 4 — after retries exhausted on "build tests," you cannot claim "tests pass."
- **+ `wiki/patterns/preflight-dependency-checks.md`** — preflight has its own retry table (typically zero-retry, fast probes).

## MAD.Council specifics

Every `/council-*` skill includes a retry table in its SKILL.md. Shared values (digest.json read, seq.json increment, message write, channel.json update) come from `mad.council.a2a.md` §10.2. Skill-specific values (A2A task/send, Council role invocation, MAD gate check) come from the spec's per-section retry notes.

When writing a new skill in `MAD/skills/<command>/SKILL.md` (iter 7-8), the retry table is a required section. No skill ships without one.

## References

- `plugins/zen-agents/agents/scrum-master.md` "Operational Limits & Retry Policy" — canonical 4-column format source.
- `plugins/zen-agents/agents/programmer.md` — zero-retry-on-expensive-ops variant.
- `plugins/zen-agents/agents/peer-reviewer.md` — variant for PR review context.
- `plugins/zen-agents/agents/feedback-collector.md` — variant for Playwright-driven ops.
- `plugins/zen-agents/agents/security-manager.md` — variant with combined timeout (3 queries in 30s total).
- `mad.council.a2a.md` §10.2 — MAD.Council's canonical table.
- `rules/degradation-fallback-policy.md` — policy this pattern implements.
- CHECKLIST cross-cutting pattern #9 — per-operation retry+timeout tables.
