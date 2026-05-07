# Degradation & Fallback Policy

**Applies to:** every `/council-*` skill + every background polling task that depends on an external resource (filesystem, CronCreate, A2A bridge, MCP server, network).

**Source:** lifted from `plugins/zen-agents/agents/orchestrator.md` §Degradation & Fallback Policy. Extended with `plugins/ai-native-team/agents/fleet-orchestrator.md` named failure-mode recovery paths.

## Core principle

A skill that completes 80% of its work with one dependency unavailable is better than one that fails entirely. Always produce whatever output is possible and clearly document what was skipped.

Failures are public. Never silent-fail, never fake success.

## The five rules

### Rule 1 — Never block on optional context

If a dependency is optional (A2A bridge when all members are local, WorkIQ MCP when not authoring a design doc, mermaid-cli when not rendering diagrams), its absence does not block the skill. Skip that path, note the gap, continue.

Optional dependencies are declared in the skill's preflight table (see `wiki/patterns/preflight-dependency-checks.md`) with `Required: Optional` or `Required: Recommended`. Only `Required: Yes` stops execution.

### Rule 2 — Always offer a manual fallback

If automated delivery fails (A2A endpoint unreachable, CronCreate unavailable, MCP server down), offer the user a manual alternative:

- A2A unreachable → output the message body + target endpoint so the user can relay by hand.
- CronCreate unavailable → offer manual-check mode where the user runs `/council-check` themselves.
- MCP server down → output the JSON payload for the user to submit through the UI.

The manual fallback is always emitted as part of the error output. Never leave the user with nothing but a failure message.

### Rule 3 — Report context gaps

Every `/council-check` output (or equivalent status-producing command) MUST include a `Context Gaps` section if any primitive was unavailable during the operation. Format:

```markdown
⚠️ Context Gaps

| Source | Status | Impact |
|---|---|---|
| digest.json | read timeout 5s, retry exhausted | Using last-known digest from 12:15 UTC |
| a2a-bridge:es-trainer@remote | connection refused | 2 outbound messages queued locally |
| threads/x3/messages/ | permission denied | Thread x3 not checked |
```

Context Gaps are **never** silent. If there are no gaps, the section is omitted. If there are gaps and the section is missing, that's a bug.

### Rule 4 — Respect retry limits

Every operation has a declared retry+timeout table (`wiki/patterns/per-operation-retry-tables.md`). When an operation exceeds its retry limit, stop retrying and follow the documented "On Failure" action. Do NOT invent additional retry strategies at runtime.

The table is the contract. If the contract isn't tight enough, update the table — don't paper over with ad-hoc retries.

### Rule 5 — Graceful partial completion

Prefer partial success with an explicit gap list over total failure. Concretely:

- `/council-check` reads 7 of 10 threads (3 unreadable) → return the 7, list 3 as gaps, do NOT fail.
- `/council-review` runs 2 of 3 roles (Architect failed) → emit verdict with "2/3 roles completed" noted, do NOT fail.
- `/council-post` delivers local but A2A transport fails → return "posted locally, A2A queued," do NOT fail.

The "graceful" qualifier matters: partial completion must be clearly differentiated from full success so callers don't consume incomplete output as complete.

## Named failure modes (from fleet-orchestrator)

Six named failure modes with canonical recovery paths. Every skill with external dependencies should handle at least the ones relevant to its operations.

### 1. No PR diff / file context available

- **Action**: state that no diff was found. Analyze repo structure from available files instead.
- **Fallback**: ask the user to specify target files or paste the relevant code.
- **Do NOT**: fabricate a diff or guess what changed.

Relevant to `/council-review` when reviewing a thread that references external code.

### 2. Very large diff (>5000 lines changed)

- **Action**: process files in batches, prioritizing `src/` over `test/` and `docs/`.
- **Fallback**: summarize changes per directory, deep-dive only where the user highlights.
- **Scope narrowing**: "This PR touches 47 files. I'll focus on the 12 source files in src/api/. Want other directories?"

Relevant to `/council-review` on long threads.

### 3. No release tags / version info found

- **Action**: fall back to the last 20 merged commits on the default branch.
- **Fallback**: ask the user for version or commit range.
- **State assumption**: "No release tags found. Using commits since [SHA] (30 days ago)."

Relevant to `/council-retro` when synthesizing retrospective context from git history.

### 4. Test framework not detected

- **Action**: infer language from file extensions; recommend a framework (Jest for TS/JS, pytest for Python, xUnit for C#).
- **Fallback**: generate framework-agnostic pseudocode with a note on the assumption.

Relevant to `/council-post --type task` when the task includes a testing scope.

### 5. Tool or API failure (timeout, rate limit, auth error)

- **Action**: report the specific failure. Do NOT produce partial or fabricated results.
- **Fallback**: "GitHub API returned 403 — rate limit exceeded. Please retry in 5 minutes or provide the data manually."
- **Stop condition**: after 2 consecutive failures on the same resource, stop retrying and report.

Relevant everywhere external services are called.

### 6. Tool-specific errors that look like policy violations

- **Action**: inspect the error. Is it a real policy violation (auth scope missing) or a transient bug (network flake presented as 403)?
- **Fallback**: if ambiguous, treat as policy violation first (safer) — ask user to re-auth or confirm scope — and fall back to retry only after policy check.

Relevant to A2A cross-org bridge calls and OAuth-protected MCP endpoints.

## Stop conditions (when degradation becomes halt)

Stop execution and report to the user when:

- **Circuit breaker opens** (3+ consecutive failures on the same resource — see `wiki/patterns/circuit-breakers.md`).
- **Trust score falls below minimum threshold** (numeric trust-tier gating; relevant in automated/daemon mode only).
- **Governance policy violation detected** in input or output (e.g. prompt-injection pattern that wasn't flagged but acted on).
- **Destructive action requested without explicit consent** (violation of `dangerous-operations-policy.md`).

Halt is always reported with:
- What was attempted
- What failed (with error codes, retry count)
- What state was persisted (so resumption is possible)
- What the user should do next

## Interaction with other policies

- **`prompt-injection-policy.md`** — a suspicious-message flag is reported as a degradation signal in Context Gaps; the policy Rule 1 flagging does not by itself halt, but accumulated flags may trip the circuit breaker.
- **`dangerous-operations-policy.md`** — a consent-timeout counts as a refusal, not a degradation. Different handling: degradation continues with a gap; refusal stops the action.
- **`stride-threat-model.md`** — degradation paths must not themselves introduce new attack surfaces (e.g. a fallback that writes to a shared location the attacker can read).

## Enforcement

Per-skill responsibilities:
- Every skill SKILL.md declares its dependency table and which rule applies to each.
- Every skill that can emit Context Gaps does so via a shared helper in `MAD/scripts/context-gaps.ps1` (future).
- Audit trail: degradation events are logged to `<channel>/degradation-log.jsonl` with `{ts, operation, source, status, impact}`.

## What this policy does NOT cover

- **Scheduled maintenance windows** — if the A2A bridge is down because it's being upgraded, that's planned; users are notified via the bridge's release channel, not through this policy.
- **Data quality issues** — a digest.json that parses fine but contains stale data is not a degradation gap in the file-read sense; it's a staleness issue surfaced via `last_updated_utc`.
- **Human availability** — a `/council-leave` consent prompt waiting for a user who has closed the terminal is a `dangerous-operations` matter, not degradation.

## References

- `plugins/zen-agents/agents/orchestrator.md` §Degradation & Fallback Policy — source text.
- `plugins/ai-native-team/agents/fleet-orchestrator.md` §Failure Modes & Recovery — six named failure modes.
- `plugins/zen-agents/agents/security-manager.md` — "Unvalidated — MS Learn unavailable" labeling convention.
- `mad.council.a2a.md` §8.3, §10.1, §10.2 — spec sections this expands.
- `wiki/patterns/circuit-breakers.md` — related; degradation escalates to circuit-break after N failures.
- `wiki/patterns/preflight-dependency-checks.md` — related; declares which dependencies are subject to this policy.
