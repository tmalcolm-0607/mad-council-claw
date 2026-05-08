# Pattern: Completion Report Protocol

**Canonical name:** Completion Report Protocol. Variants: *handoff report*, *session summary*, *exit log*, *state-closing artifact*.

**One-line definition:** Every agent that completes a discrete work unit emits a structured report describing what it did, what state resulted, and what (if anything) is pending for the next agent. Orchestrators route on the report; humans audit with it.

## When to use

- Multi-agent workflows where one agent's completion is another's trigger.
- Long-running sessions where "what did this session accomplish" needs to persist after the session ends.
- Any stateful workflow where a session-boundary carries meaning (leaving a channel, ending a review, closing an incident).
- Audit trails for regulated environments.

## When NOT to use

- Single-shot agents with no downstream consumer. A function returning a value is enough.
- Stateless operations where the output speaks for itself (a code review verdict IS its own report).
- Interactive chat where the human is in the loop on every step — the chat log is the report.

## Core mechanics

```
Agent completes its task
         ↓
Determine state (from a declared state machine)
         ↓
Emit structured JSON: what was done + what state resulted + what's pending
         ↓
Persist to a known location (e.g., <channel>/leave-reports/<alias>-<ts>.json)
         ↓
Human-readable summary rendered inline
         ↓
Orchestrator routes on the state field
```

Two parts to the report:

1. **Machine-readable** — JSON with a versioned schema. Enables orchestrator routing, audit queries, post-hoc analysis.
2. **Human-readable** — inline summary shown to the user. Tells them what just happened without making them parse JSON.

## Canonical schema (from zen-agents/peer-reviewer)

```json
{
  "schema_version": 1,
  "agent": "peer-reviewer",
  "session_id": "sess-abc123",
  "run_id": "<guid>",
  "completed_utc": "2026-04-17T14:30:00Z",
  "state": "PEER_REVIEWED",
  "artifacts": [
    { "type": "review-comment", "path": "PR #14706166 threads", "count": 12 },
    { "type": "summary", "path": "./output/peer-review-14706166.md" }
  ],
  "outcomes": {
    "findings_critical": 0,
    "findings_high": 2,
    "findings_medium": 5,
    "findings_nit": 3
  },
  "context_gaps": [
    { "source": "microsoft-docs-mcp", "status": "timeout", "impact": "some design decisions unvalidated" }
  ],
  "next_state_hint": "PR_FEEDBACK_ADDRESSED or READY_TO_MERGE, per orchestrator routing table"
}
```

Field semantics:

- **`state`** — the driving field. Orchestrators use this to decide what happens next. Canonical states are declared in the workflow's state machine (e.g., `DESIGN_CREATED`, `DESIGN_REVIEWED_R1`, `PEER_REVIEWED`, `IMPLEMENTED`, `PR_FEEDBACK_ADDRESSED`).
- **`artifacts`** — where the work product lives. A reader can follow these paths to see the actual output.
- **`outcomes`** — quantified summary. Counts, scores, pass/fail.
- **`context_gaps`** — degradation report (inherits from `degradation-fallback-policy.md` Rule 3).
- **`next_state_hint`** — an advisory note, not a decision. The orchestrator owns routing.
- **`run_id`** — correlation key (from `run-id-correlation.md`). Ties the report to the same work unit as upstream messages.

## Common implementations

### Marketplace: zen-agents (canonical, 9-agent fleet)

Every `zen-agents` agent emits a Completion Report. The orchestrator reads the report and routes to the next agent via a labeled handoff button. The protocol is so pervasive in zen-agents that every agent frontmatter declares it explicitly:

> "When you complete your work, you MUST output a Completion Report at the end of your response."
> "You do NOT decide the next step. The orchestrator owns all routing decisions."

Benefits:
- Clean decoupling — each agent only decides its own state; orchestrator owns transitions.
- State machine is explicit — `DESIGN_CREATED`, `DESIGN_REVIEWED_R1`, `DESIGN_R1_ADDRESSED`, `DESIGN_REVIEWED_R2`, ... — no ambiguity about where you are.
- Auditable — every agent's output is parseable.

### Marketplace: sfi-dev-toolkit/remediation-review

Completion Report shape specialized for learning signals:

```json
{
  "run_id": "<guid>",
  "kpi_id": "ID2.1.9",
  "session_summary": {
    "changes_proposed": "...",
    "changes_applied": true,
    "developer_accepted": true,
    "developer_modified": false,
    "escalation_needed": false,
    "turns_taken": 4,
    "pr_url": "..."
  }
}
```

Used for ALAS (Agentic Learning and Assessment System) — paired with the outcome signal from the quality evaluator, gives a "what was self-reported vs what the outcome was" learning signal.

### Marketplace: agent-native-toolkit/content-quality-loop

Iteration-level reports: each of up to 3 iterations emits a mini-report; the overall loop emits a final report consolidating.

### LangGraph checkpointing

Language-level analog. The graph's state at each node is persisted; the final state at a terminal node is the "report." LangGraph doesn't prescribe a schema, but the persistence pattern is the same.

## MAD.Council implementation

`/council-leave` emits a Completion Report per `mad.council.a2a.md` §9.2:

```json
{
  "schema_version": 1,
  "alias": "Training Worker",
  "session_id": "sess-def456",
  "channel": "es-training",
  "left_utc": "2026-04-17T14:30:00Z",
  "contributions": {
    "threads_created": 3,
    "threads_resolved": 1,
    "threads_participated": 5,
    "tasks_picked_up": 4,
    "tasks_completed": 3,
    "tasks_dropped": 1,
    "questions_asked": 2,
    "questions_answered": 5,
    "verdicts_issued": 1
  },
  "final_state": {
    "was_last_member": false,
    "channel_archived": false,
    "verdict_pending": ["thread-x3"]
  },
  "run_ids_involved": ["<guid>", "<guid>", "<guid>"]
}
```

Stored at `<channel>/leave-reports/<alias>-<timestamp>.json`. Human-readable version rendered inline at leave time.

Also: `/council-review` produces a verdict.json which is a specialized form of Completion Report (the "state" field is the verdict type).

## Pros

- **Clean agent-to-agent handoff**: reports are the contract. No ambiguity about what one agent delivered to the next.
- **Auditability**: post-hoc, you can answer "what did agent X contribute?" in seconds.
- **Routing primitive**: orchestrators route on `state`. No LLM judgment needed for workflow advancement.
- **Learning signals**: correlate self-reported outcomes with independent evaluations (SFI pattern).
- **Stateful workflows across sessions**: a report from yesterday can drive today's orchestrator.

## Cons

- **Schema drift**: every new agent wants to add fields. Versioning + strict review prevent chaos.
- **Overhead for simple agents**: a 2-step agent emitting a full report is bureaucratic.
- **Honest self-assessment is hard**: agents tend to inflate outcomes. Pair with independent evaluation (SFI's two-signal approach).
- **User may skip the human-readable part** and miss important warnings. Mitigate by surfacing Context Gaps prominently.

## Do / Don't

**Do**:

- **Version the schema** — `schema_version: N`. Makes backward-compat explicit.
- **Use a declared state machine** — don't invent states ad hoc per report.
- **Include `run_id`** — enables cross-artifact correlation.
- **Include Context Gaps** — degradation details belong in the report, not just in session output.
- **Render a human-readable summary** alongside the JSON — most readers won't parse JSON by hand.
- **Persist to a predictable path** — `<channel>/leave-reports/<alias>-<ts>.json` or similar. Searchable.
- **Value honesty over optimism** — SFI's "deliberately low scores valued over inflated 5s" principle applies.
- **Let orchestrators own routing** — the report's `next_state_hint` is advisory.

**Don't**:

- **Don't decide the next step inside the report.** You describe what you did; the orchestrator decides what's next.
- **Don't skip Context Gaps** when degradation occurred. The consumer needs to know.
- **Don't embed raw content blobs** in the report. Reference paths, not inline paste.
- **Don't emit partial reports silently** — if the agent crashes, the report isn't emitted and the orchestrator must handle the absence explicitly.
- **Don't rewrite existing reports** — they're append-only artifacts. Corrections are new reports that supersede.
- **Don't conflate "completed successfully" with "produced useful output"** — an agent that completes a degenerate input may have nothing to report; say so rather than fabricating outcomes.

## Interaction with other patterns

- **+ `orchestrator-worker.md`**: reports are the worker → orchestrator handoff.
- **+ `run-id-correlation.md`**: reports carry the run_id; post-hoc queries filter by it.
- **+ `degradation-fallback-policy.md`**: Context Gaps in reports implement Rule 3.
- **+ `multi-role-review.md`**: Council verdicts are specialized reports (state = verdict type).
- **+ `learning-signals.md`** (future): reports feed the learning-signal correlation loop.

## References

- `plugins/zen-agents/agents/peer-reviewer.md` §Completion Report Protocol — canonical source.
- `plugins/zen-agents/agents/programmer.md`, `scrum-master.md`, `system-design-author.md`, etc. — same protocol, per-agent variants.
- `plugins/sfi-dev-toolkit/skills/remediation-review/SKILL.md` — learning-signal variant.
- `plugins/agent-native-toolkit/agents/content-quality-loop.md` — iteration-level reports.
- LangGraph checkpointing — https://langchain-ai.github.io/langgraph/concepts/persistence/
- `mad.council.a2a.md` §9.2 — spec section.
- CHECKLIST cross-cutting pattern #20 — Completion Report Protocol.
