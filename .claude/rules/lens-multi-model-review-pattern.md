---
name: lens-multi-model-review-pattern
description: Cross-model parallel review pattern (Claude + GPT via Copilot CLI) for security/architectural decisions where multi-model agreement reduces single-model bias.
status: preview
since: 2026-05-02
last_reviewed: 2026-05-02
promote_by: 2026-08-02
---

# Rule — LENS multi-model review pattern

> **Status: preview.** Vendored from `lens-multi-model-review` plugin (Shayon Gupta, LENS-Common PR #5138039). Dispatcher implemented at `.claude/scripts/Invoke-CopilotMultiModel.ps1` (lines 41-141). Wording stays preview until the council ratifies cross-model agreement semantics.

## What it is

A parallel cross-model review: the same brief + diff is dispatched simultaneously to **Claude Opus** and **GPT-5+** (or whichever models the local Copilot CLI exposes). Both produce structured findings; a synthesis step builds a cross-model agreement table. **When both models flag the same CRITICAL pattern, the finding is treated as a hard block.** When the models disagree, the divergence itself is signal — usually meaning the area needs a closer human read.

The point is not to "pick the better model" — it is to use the two as adversarial cross-checks. A single-model review carries that model's blind spots; a two-model review reduces those blind spots wherever the models' biases are uncorrelated (in practice: most Claude/GPT blind spots are uncorrelated for security reviews).

## When to use

Inherit this pattern in any skill where multi-model agreement is materially valuable:

| Scenario | Why two models help |
|---|---|
| Security review | Each model misses different attack classes; AND-of-flags raises precision |
| Contract migration | Cross-model agreement on shape changes catches breaking changes one model would rationalize away |
| Architectural decision | Two independent architects beats one architect twice |
| Cross-cutting prescriptive content (rules, kit-wide skills) | High blast-radius per `prescriptive-content-review.md` Gap 5 — auto-escalate to multi-model when blast_radius ≥ 7 |

**Do not use** for routine implementation review, mechanical-fix verification, or pure-style nits — the cost is not justified.

## Mechanism

The orchestrator (or inheriting skill) **never invokes the dispatcher script directly** — that would violate `orchestrator-identity.md` Rule 1 ("ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF"). Instead, the orchestrator spawns a Task-tool subagent and the subagent runs the dispatcher.

**Canonical invocation shape (Task-tool subagent spawn):**

1. Orchestrator (or inheriting skill) decides `--copilot` mode is active for this run.
2. Orchestrator spawns a Task subagent with this brief:
   - `subagent_type: general-purpose`
   - prompt: includes the prompt file path, dispatcher path, `OutputDir`, and instruction to invoke the dispatcher and return the cross-model agreement table
3. Subagent runs:

   ```powershell
   pwsh -NoProfile -File .claude/scripts/Invoke-CopilotMultiModel.ps1 `
     -PromptFile <path-to-brief.md> `
     -OutputDir <path-to-output-dir>
   ```
4. Subagent reads `<OutputDir>/opus-result.json` + `<OutputDir>/gpt-result.json`, builds the cross-model agreement table, and returns the table to the orchestrator.
5. Orchestrator integrates the agreement table into its synthesis (does not re-read the raw `*-result.json` files itself).

This honors `orchestrator-identity.md`: the orchestrator orchestrates; the subagent does the dispatch work. The orchestrator's tool surface stays minimal (Task, Read of subagent output) — it does not gain Bash for dispatcher invocation.

**What the dispatcher does (per `skill-standards.md` § Dimension 6):**

1. Detects Copilot CLI: `which copilot` / `which agency`.
2. Saves the brief + diff to `$TEMP_DIR`.
3. Spawns two `copilot --yolo -p ...` processes in parallel — one targeting Opus, one targeting GPT-5+.
4. Waits for both to complete.
5. Writes structured outputs to `<OutputDir>/opus-result.json` and `<OutputDir>/gpt-result.json`.

## Inheritance contract

Inheriting skills declare `--copilot` mode in 5 lines. The skill body adds:

```markdown
## `--copilot` mode

See `rules/lens-multi-model-review-pattern.md`.

Skill-specific synthesis lens: <one-line rationale, e.g. "PR diff + applicable patterns; security + correctness cross-check">.
```

The skill frontmatter adds:

```yaml
inherits-rules:
  - rules/lens-multi-model-review-pattern.md
```

**The contract:**

| What the inheriting skill provides | What this rule provides |
|---|---|
| Synthesis lens (one-line rationale: which dimension of the artifact warrants cross-model verification) | The Task-tool subagent-spawn mechanism |
| When to invoke `--copilot` (auto-escalation triggers, user opt-in, etc.) | The cross-model agreement table shape |
| How findings integrate into the skill's own output | The fallback shape (same-model role-split when Copilot CLI is missing) |
| Skill-specific severity calibration | The both-flag-CRITICAL hard-block rule |

The inheriting skill MUST NOT redefine the dispatch mechanism, the agreement-table shape, or the hard-block rule. Those belong to the rule. If a skill needs a variant, propose a rule amendment via `/council-review` rather than forking.

## Output

The orchestrating skill consumes:

```json
{
  "OpusResultPath": "<dir>/opus-result.json",
  "GptResultPath":  "<dir>/gpt-result.json"
}
```

It then builds the **cross-model agreement table**:

| Finding | Opus | GPT | Decision |
|---|---|---|---|
| F1 (CRITICAL: SQL injection) | flagged | flagged | **HARD BLOCK** |
| F2 (MAJOR: missing auth check) | flagged | not-flagged | SHOULD-FIX (one-model signal) |
| F3 (MINOR: naming) | not-flagged | flagged | CONSIDER (one-model signal) |

**Both-flag-CRITICAL → hard block.** A finding flagged CRITICAL by both models cannot be dismissed by the orchestrator; the only paths forward are `wait-for-author` or `reject`.

## Fallback (Copilot CLI unavailable)

When the Copilot CLI is not installed (typical for fresh kit installs or CI environments without Copilot), fall back to two parallel `Task` calls with role-distinguishing prompts on the **same model**:

- `subagent_type: general-purpose` for both lanes (not domain-specialized — the role split lives in the prompt, not in the agent type).
- Role A prompt: "Act as a security-first reviewer. Flag every plausible attack class."
- Role B prompt: "Act as a correctness-first reviewer. Flag every plausible spec deviation."

Same orchestration shape (parallel dispatch → agreement table → both-flag-CRITICAL hard block); **weaker disagreement signal** because both lanes share the same model's blind spots.

**Context Gap line.** The orchestrator MUST emit the following line in its output (per `degradation-fallback-policy.md` Rule 3):

> Copilot CLI unavailable; using same-model role-split fallback. Cross-model signal weaker.

**Consent gate (first-use per session).** The first time `--copilot` is invoked in a session, the orchestrator MUST emit an `AskUserQuestion` consent prompt per `dangerous-operations-policy.md` § Cross-org A2A Bridge category (Copilot CLI dispatch is cross-process egress to a third-party model endpoint and is treated as the equivalent boundary). The prompt previews the brief, the target models (Claude Opus + GPT-5+), and the OutputDir, and waits for explicit "yes". Subsequent `--copilot` calls in the same session reuse that consent — the user is not re-prompted per invocation. The consent decision is logged to `<channel>/consent-log.jsonl` per the dangerous-operations enforcement table.

The consent gate does NOT fire for the same-model fallback path (no third-party egress occurs).

## Reference

- Shayon Gupta, LENS-Common PR #5138039 — original `lens-multi-model-review` plugin.
- `.claude/scripts/Invoke-CopilotMultiModel.ps1` — local dispatcher (param block lines 41-53; Copilot CLI detection lines 71-82; parallel Start-Job dispatch lines 108-122).
- `.claude/rules/skill-standards.md` § Dimension 6 — the inheritance contract.
- `.claude/rules/prescriptive-content-review.md` § Gap 5 — auto-escalation trigger (`blast_radius ≥ 7`).
- `.claude/rules/orchestrator-identity.md` Rule 1 — "ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF"; basis for the Task-tool subagent-spawn shape.
- `.claude/rules/dangerous-operations-policy.md` § Cross-org A2A Bridge — basis for the first-use-per-session consent gate.
- `.claude/rules/degradation-fallback-policy.md` Rule 3 — Context Gap reporting requirement on fallback path.
- `.mad/reports/d8-council-verdict-iter3b2-matrix-2026-05-02.md` MX2 — the verdict pinning this mechanism.
