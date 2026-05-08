# Pattern: run_id Correlation

**Canonical name:** run_id / session correlation / trace identifier propagation. Also called *correlation key*, *trace ID*, *session ID propagation*.

**One-line definition:** Generate a GUID at the start of a work unit; propagate it through every message, sub-action, tool call, and artifact produced during that unit; use it later to reconstruct the whole flow.

## When to use

- Multi-step work where "what happened in step N?" needs to be traceable.
- Systems with learning signals or observability requirements.
- Workflows that span sessions (reply to something posted days ago) — the run_id ties a conversation lineage together.
- Any system where a single user request fans out into many downstream actions.

## When NOT to use

- Single-request-single-response interactions. The URL / call ID is already sufficient.
- Stateless operations with no persisted output. Nothing to correlate *to*.
- Systems where you control the trace boundary some other way (OpenTelemetry trace ID etc.). Don't invent a parallel ID.

## Core mechanics

```
Session start → generate GUID → store as run_id
       ↓
Every message, every sub-action, every tool call inherits run_id
       ↓
Artifacts (files, reports, retros) are tagged with run_id
       ↓
Later: grep / query by run_id reconstructs the full flow
```

Two propagation rules are canonical:

1. **Generate once per "work unit"** — what constitutes a work unit depends on the system. For MAD.Council, it's "one /council-open session by one member." For SFI, it's "one remediation session for one KPI."

2. **Inherit, don't regenerate, for replies and continuations** — when an agent replies to a message with run_id `G1`, the reply's run_id is also `G1`. Replies inherit; new work units generate.

## Common implementations

### Marketplace: plugins/sfi-dev-toolkit (canonical)

Verbatim from `sfi-dev-orchestrator.md` Step 0:

```powershell
$run_id = [guid]::NewGuid().ToString()
```

Then propagated to:
- Every skill invocation (passed as parameter).
- Every learning signal (remediation-review, mise-v2-pr-quality-evaluator).
- Every PR comment (stamped as HTML comment tag).
- Every ALAS hub issue (for cross-signal correlation).

**Pros**: Single source of truth; survives session restart; post-hoc analysis is trivial (`grep <guid> *.json`).

**Cons**: If a bug causes run_id to not propagate, the trace breaks silently. Mitigate with schema enforcement.

### Marketplace: plugins/typescript-updater

Different terminology — calls it `sessionId` — but same pattern. Every tool call in the upgrade flow carries the sessionId so the tool can correlate state across calls. Uses it for resumability: partial upgrade results can be queried by sessionId and resumed.

### OpenTelemetry / distributed tracing

Industry-standard implementation. `traceparent` W3C header propagates across HTTP boundaries. Sub-spans inherit the trace ID automatically.

**Pros**: Standardized; tooling ecosystem (Jaeger, Zipkin, etc.).

**Cons**: Designed for service-to-service RPC, not for markdown/file-based workflows. Adopting OTel for MAD.Council is overkill unless you already have the infrastructure.

### A2A Protocol task IDs

A2A's `task_id` is a correlation primitive at the protocol level. Every message within an A2A task carries the task_id. MAD.Council's run_id and A2A's task_id are complementary — run_id is our correlation, task_id is A2A's; both appear on the message.

### Agent learning systems (ALAS-style)

Internal agent-learning systems (e.g. ALAS) correlate agent execution signals (what the skill did) with outcome signals (what the human accepted / what quality score the PR got) via shared run_id. The gap between self-assessment and independent outcome is the learning signal.

## Pros

- **Post-hoc reconstruction**: `grep <run_id> **/*.json` finds every artifact from a single run.
- **Cross-system correlation**: if SFI emits run_id X and MAD.Council emits the same run_id X for downstream work, both systems' logs tie together.
- **Cheap**: a GUID is 36 bytes. Propagation cost is negligible.
- **Survives restarts**: written to files; doesn't live in ephemeral memory.
- **Enables learning signals**: the "execution signal vs outcome signal" gap (SFI remediation-review pattern) requires a shared correlation key.

## Cons

- **Silent failure if not propagated**: if a bug drops the run_id on one message, you have a split trace. Schema validation at post time mitigates.
- **PII risk if tied to user identity**: a GUID alone is fine, but if you also log user alias + project, the combination is identifying. Keep the run_id abstract.
- **Not cryptographically meaningful**: run_id is not a signature. A malicious actor can forge one. Use `session_id` binding for authenticity.
- **Storage cost at scale**: if you log millions of messages, GUIDs add up. Consider compact IDs (ULIDs, Snowflake) for high-volume systems.

## Do / Don't

**Do**:

- **Generate at work-unit start**, not per-message. A session-long run_id is normal.
- **Include in every persisted artifact**: messages, verdicts, reports, retros, archives.
- **Preserve across reply chains**: a reply to a message with run_id X gets run_id X, not a new one.
- **Preserve across archival**: the archived copy keeps the run_id — that's the whole point of post-hoc queries.
- **Store as GUID**: any RFC 4122 variant is accepted; v4 (random) is recommended because collision probability is effectively zero and no time/MAC ordering leaks. Canonical printed form is 36 chars `xxxxxxxx-xxxx-Mxxx-Nxxx-xxxxxxxxxxxx`. The spec (`mad.council.a2a.md §7.3`) declares `run_id: GUID?` without pinning a version — v4 is convention, not a schema gate.
- **Make it optional at the schema level, mandatory at the convention level**: schema says `run_id?: string`; convention says "always populate."
- **Render only when asked**: don't clutter `/council-check` output with GUIDs. Make it `--with-run-ids` to surface them.

**Don't**:

- **Don't use the run_id for auth** — it's a trace ID, not an authentication token. Auth is `session_id` + OAuth (A2A).
- **Don't regenerate on every sub-action** — that defeats correlation. New work unit only.
- **Don't couple to user identity** — the run_id belongs to the work, not the user. Keep them separate fields.
- **Don't log run_id without the message it belongs to** — a GUID alone is useless without context.
- **Don't parse run_ids to infer meaning** — they're opaque. Any structure inside is coincidental; don't depend on it.

## Interaction with other patterns

- **+ `completion-report-protocol.md`**: reports include `run_ids_involved: []` listing every run_id the session touched. Cross-correlation.
- **+ `orchestrator-worker.md`**: orchestrator generates the run_id; workers inherit it.
- **+ `multi-role-review.md`**: Council findings inherit the thread's run_id so post-hoc "what did this review cost / find / decide" queries work.
- **+ `state-file-coordination.md`**: channel.json stores the `created_with_run_id`; messages store their own; the match lets you reconstruct "which session created this channel."
- **+ `learning-signals.md`**: remediation-review + quality-evaluator tie together via run_id. The gap between self-assessment score and outcome score is the learning.

## MAD.Council specifics

- Generated at session start per `mad.council.a2a.md` §9.1.
- Written to `channel.json` `created_with_run_id` on `/council-open`.
- Written to every message's `run_id` field on `/council-post`.
- Inherits across `--reply-to` (reply takes original message's run_id).
- Matches across verdicts and retros — verdict.json shows the run_id of the thread's last message; retro shows the run_ids of the whole channel's activity.
- Hidden from `/council-check` output by default; shown with `--with-run-ids`.
- Preserved in archival — archived channels retain run_ids for audit.

## References

- `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md` "Step 0: Generate Session run_id" — canonical marketplace implementation.
- `plugins/sfi-dev-toolkit/skills/remediation-review/SKILL.md` — uses run_id to correlate execution + outcome signals.
- `plugins/sfi-dev-toolkit/skills/mise-v2-pr-quality-evaluator-skill/SKILL.md` — PR quality eval correlated by run_id.
- `plugins/typescript-updater/` — sessionId variant; same pattern.
- W3C traceparent spec — https://www.w3.org/TR/trace-context/
- OpenTelemetry Trace API — https://opentelemetry.io/docs/specs/otel/trace/
- `mad.council.a2a.md` §9.1 — the spec section this pattern implements.
- CHECKLIST cross-cutting pattern #3 — run_id GUID correlation.
