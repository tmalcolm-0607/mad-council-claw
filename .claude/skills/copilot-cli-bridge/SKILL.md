---
name: copilot-cli-bridge
description: Canonical wrapper for cross-model dispatch via Copilot CLI; the entry point inheriting skills invoke when running --copilot mode (multi-model security/architectural review).
allowed-tools:
  - Read
  - Glob
  - Task
disable-model-invocation: false
version: 1.0.0
inherits-rules:
  - rules/lens-multi-model-review-pattern.md
  - rules/orchestrator-identity.md
  - rules/dangerous-operations-policy.md
  - rules/degradation-fallback-policy.md
  - rules/skill-standards.md
references:
  - m-main/src/services/copilot.ts
  - m-main/.copilot/mcp-config.json
  - .claude/scripts/Invoke-CopilotMultiModel.ps1
  - .claude/rules/lens-multi-model-review-pattern.md
tier-target: S
tier-exempt: [evals, templates]
---

# Skill — `copilot-cli-bridge`

The canonical kit-wrapper for cross-model dispatch via Copilot CLI. Inheriting skills (e.g., `pr-review --copilot`, `code-reviewer --copilot`, `mcp-permission-validate --copilot` when adding to an allowlist, future security-critical reviews) call this skill instead of duplicating the dispatcher invocation logic. The skill is **orchestration glue**: it spawns a Task subagent that runs the existing `.claude/scripts/Invoke-CopilotMultiModel.ps1` dispatcher, parses the cross-model output, builds the agreement table, and returns it to the caller.

This skill enforces the contract from `lens-multi-model-review-pattern.md`: the orchestrator NEVER invokes the dispatcher directly (that would violate `orchestrator-identity.md` Rule 1 — "ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF"). The skill spawns a subagent; the subagent runs the dispatcher; both models' results synthesize into a single agreement table the caller acts on.

## When to use

| Scenario | Why use cross-model dispatch |
|---|---|
| Security review | Each model misses different attack classes; AND-of-flags raises precision per `lens-multi-model-review-pattern.md` § When to use |
| Architectural decision | Two independent architects beats one architect twice |
| Contract migration (schema breaks, API renames) | Cross-model agreement on shape changes catches breaking changes one model would rationalize away |
| Cross-cutting prescriptive content (rules, kit-wide skills) — `blast_radius ≥ 7` | Auto-escalate per `prescriptive-content-review.md` § Gap 5 |
| MCP allowlist expansion (new server entry) | High blast-radius — every consumer downstream affected |

**Do NOT use** for routine implementation review, mechanical-fix verification, or pure-style nits — the cost is not justified per `lens-multi-model-review-pattern.md` § When to use.

## Inputs

| Input | Type | Required | Detail |
|---|---|---|---|
| `prompt-file` | path | yes | Path to the markdown brief (review prompt + diff/context) the dispatcher will send to both models |
| `output-dir` | path | no | Where the dispatcher writes `opus-result.json` + `gpt-result.json`. Defaults to `.mad/scratch/multimodel-<ts>-<rand>/` per `Invoke-CopilotMultiModel.ps1:130-132` |
| `model1` | string | no | First model ID. Default: `claude-opus-4.7` per `Invoke-CopilotMultiModel.ps1:78` |
| `model2` | string | no | Second model ID. Default: `gpt-5.5` per `Invoke-CopilotMultiModel.ps1:80` |
| `synthesis-lens` | string | yes | One-line rationale documenting which dimension warrants cross-model verification (per `lens-multi-model-review-pattern.md` § Inheritance contract). E.g., "Security review: SQL injection + auth bypass cross-check" |
| `timeout-seconds` | int | no | Hard cap on dispatcher wall-clock. Default: 600 per `Invoke-CopilotMultiModel.ps1:84`. Was 120 pre-2026-05; raised after empirical calibration. |
| `fallback-on-missing-cli` | bool | no | When Copilot CLI is missing, fall back to two parallel Task calls on the same model with role-distinguished prompts. Default: true per `Invoke-CopilotMultiModel.ps1:82` |

## Outputs

The skill returns a JSON object to the calling skill:

```json
{
  "Mode": "CopilotCLI | TaskFallback | Timeout | ConcurrencyLimited",
  "OpusResultPath": "<dir>/opus-result.json | null",
  "GptResultPath":  "<dir>/gpt-result.json | null",
  "ModelsRun": ["claude-opus-4.7", "gpt-5.5"],
  "AgreementTable": [
    { "id": "F1", "severity": "CRITICAL", "title": "...", "opus": "flagged", "gpt": "flagged", "decision": "HARD BLOCK" },
    { "id": "F2", "severity": "MAJOR", "title": "...", "opus": "flagged", "gpt": "not-flagged", "decision": "SHOULD-FIX (one-model signal)" }
  ],
  "ContextGap": "Copilot CLI unavailable; using same-model role-split fallback. Cross-model signal weaker. | null",
  "TimeoutSecondsUsed": 600
}
```

The shape is sourced from `Invoke-CopilotMultiModel.ps1:97-122` (`New-DispatcherResult` helper). Per M2 hardening (`Invoke-CopilotMultiModel.ps1:97-103`): every non-`CopilotCLI` mode returns `null` paths so callers cannot blindly Read non-existent files.

## Workflow

### Step 0 — Preflight

1. Validate `prompt-file` exists (Read tool); reject if missing per `Invoke-CopilotMultiModel.ps1:124-127`.
2. Resolve `output-dir`; create if absent.
3. Verify the dispatcher exists at `.claude/scripts/Invoke-CopilotMultiModel.ps1` (Glob check).
4. Confirm `synthesis-lens` is non-empty per `lens-multi-model-review-pattern.md` § Inheritance contract.
5. Check session-scoped consent state (Step 1).

### Step 1 — First-use-per-session consent gate

Per `lens-multi-model-review-pattern.md` § Fallback (Consent gate paragraph) AND `dangerous-operations-policy.md` § Cross-org A2A Bridge category: the FIRST `--copilot` invocation in a session is treated as cross-process egress to a third-party model endpoint and requires explicit user consent.

1. Check `.mad/scratch/copilot-cli-bridge-consent-<session-id>.json`. If present and `confirmed: true`: skip prompt; reuse consent.
2. If absent: emit AskUserQuestion preview:
   ```
   About to dispatch cross-model review via Copilot CLI:
     Brief:    <prompt-file> (<size> bytes)
     Models:   <model1>, <model2>
     OutputDir: <output-dir>
     Synthesis: <synthesis-lens>
   This sends the brief to a third-party model endpoint (Copilot CLI dispatch).
   Proceed? (yes/no)
   ```
3. On `yes`: write `.mad/scratch/copilot-cli-bridge-consent-<session-id>.json` with `{confirmed: true, ts: <iso>}` and proceed.
4. On `no` or 60s timeout (per `dangerous-operations-policy.md` § Enforcement): refuse; return `{Mode: "ConsentRefused", ...all-null-paths}` and log to `<channel>/consent-log.jsonl` if a channel is active.

The consent gate does NOT fire for the same-model fallback path (no third-party egress) — but the flag does cover the consent for the dispatcher invocation itself. See Step 5.

### Step 2 — Spawn Task subagent (orchestrator-identity discipline)

Per `orchestrator-identity.md` Rule 1 + `lens-multi-model-review-pattern.md` § Mechanism: the orchestrator MUST NOT invoke the dispatcher directly. Spawn a Task subagent.

1. Construct subagent brief:
   ```
   Subagent task — cross-model dispatch
   Subagent type: general-purpose
   You will:
     1. Run this exact command (always quote arg values; the dispatcher passes them as positional args to the Copilot CLI, and unquoted paths/values with spaces or shell metacharacters get reinterpreted before PowerShell parameter binding):
        pwsh -NoProfile -File "<absolute-path-to-Invoke-CopilotMultiModel.ps1>" `
          -PromptFile "<path-to-brief.md>" `
          -OutputDir "<path-to-output-dir>" `
          -Model1 "<model1>" `
          -Model2 "<model2>" `
          -TimeoutSeconds <timeout-seconds> `
          -FallbackToTask:$<fallback-on-missing-cli>
     2. Capture the JSON result from stdout (the dispatcher emits a JSON object).
     3. If Mode == "CopilotCLI": Read both opus-result.json and gpt-result.json; produce a cross-model agreement table per the rule's table format (Finding | Opus | GPT | Decision).
     4. If Mode != "CopilotCLI" (TaskFallback / Timeout / ConcurrencyLimited): return the dispatcher result without an agreement table; the orchestrator will degrade per fallback contract.
     5. Return the structured result to the orchestrator as your final assistant message.

   Enumerate exhaustively. No Top-N capping. Every finding classified and acted upon. State 'no findings' explicitly when a category is empty.
   ```

   **Quoting note**: every path and string-valued model ID MUST be quoted in the dispatcher invocation. The dispatcher passes these as positional args to the Copilot CLI; unquoted values with spaces (`C:\Program Files\...`) break parameter binding, and unquoted values with shell metacharacters (`;`, `&`, `$()`, backticks) get reinterpreted by the parent shell before PowerShell sees them. Numeric args (`-TimeoutSeconds`) and boolean switch args (`-FallbackToTask:$true`) follow PowerShell native syntax.
2. Spawn the subagent (Task tool, `subagent_type: general-purpose`).
3. Wait for completion (no `run_in_background` — `non-negotiable-rules.md` forbids it).

The subagent does the Bash/Read work; the orchestrator stays minimal-surface (Task + Read of subagent output). This is the canonical orchestrator-worker pattern.

### Step 3 — Parse subagent output

When the subagent returns:

1. Parse the JSON result envelope.
2. Validate `Mode` is one of: `CopilotCLI | TaskFallback | Timeout | ConcurrencyLimited | ConsentRefused`.
3. If `Mode == "CopilotCLI"`: extract the agreement table from the subagent's output.
4. If `Mode == "TaskFallback"`: extract findings from the same-model role-split outputs; build a degraded agreement table; emit Context Gap per Step 5.
5. If `Mode == "Timeout"`: record `TimeoutSecondsUsed`; emit Context Gap; return without agreement table.
6. If `Mode == "ConcurrencyLimited"`: 4th simultaneous dispatch refused per `Invoke-CopilotMultiModel.ps1:138-148`; emit "Concurrency cap reached (3 parallel dispatches); retry in <N> seconds" gap.

### Step 4 — Build cross-model agreement table

For `Mode == "CopilotCLI"`: synthesize the table per `lens-multi-model-review-pattern.md` § Output:

| Finding | Opus | GPT | Decision |
|---|---|---|---|
| F1 (CRITICAL: <title>) | flagged | flagged | **HARD BLOCK** |
| F2 (MAJOR: <title>) | flagged | not-flagged | SHOULD-FIX (one-model signal) |
| F3 (MINOR: <title>) | not-flagged | flagged | CONSIDER (one-model signal) |
| F4 (CRITICAL: <title>) | flagged | not-flagged | MUST-FIX (single-model CRITICAL — escalate) |

Decision rules:
1. **Both flag CRITICAL → HARD BLOCK.** Per `lens-multi-model-review-pattern.md` § Output: cannot be dismissed by orchestrator; only paths forward are `wait-for-author` or `reject`.
2. **Both flag MAJOR → MUST-FIX.**
3. **One flags CRITICAL, one does not → MUST-FIX (escalate one-model).** Per `lens-multi-model-review-pattern.md` § Inheritance contract — disagreement is signal that the area needs a closer human read.
4. **One flags MAJOR/MINOR, one does not → SHOULD-FIX or CONSIDER (single-model signal).**
5. **Neither flags → no entry.**

When both models produce zero findings: state explicitly "Cross-model agreement: no findings flagged by either model." Do NOT pad.

### Step 5 — Context Gap reporting (degraded modes)

When `Mode != "CopilotCLI"`, emit the Context Gap line per `lens-multi-model-review-pattern.md` § Fallback (Context Gap line) AND `degradation-fallback-policy.md` Rule 3:

| Mode | Context Gap line |
|---|---|
| `TaskFallback` | "Copilot CLI unavailable; using same-model role-split fallback. Cross-model signal weaker." |
| `Timeout` | "Cross-model dispatch timed out at <N>s; both jobs stopped. No agreement table available." |
| `ConcurrencyLimited` | "Concurrency cap (3 parallel dispatches) reached on this machine; retry shortly." |
| `ConsentRefused` | "User declined Copilot CLI dispatch; cross-model verification skipped." |

The caller's report MUST include this line in its output. Per `degradation-fallback-policy.md` Rule 3: gaps are never silent.

### Step 6 — Return to caller

Return the JSON envelope from Step 4 to the calling skill. The calling skill consumes:
- `AgreementTable` for synthesis into its own report.
- `Mode + ContextGap` for degradation reporting.
- `OpusResultPath / GptResultPath` ONLY when `Mode == "CopilotCLI"` — otherwise `null` (per M2 hardening, `Invoke-CopilotMultiModel.ps1:97-103`).

### Step 7 — Exit codes

| Code | Meaning |
|---|---|
| 0 | Mode == CopilotCLI; agreement table produced |
| 1 | Mode == TaskFallback; degraded agreement table produced |
| 2 | Mode == Timeout |
| 3 | Mode == ConcurrencyLimited |
| 4 | Mode == ConsentRefused |
| 5 | Preflight failure (prompt file missing, dispatcher missing, etc.) |

## `--copilot` mode

Inheriting skills declare `--copilot` mode via the 5-line block per `lens-multi-model-review-pattern.md` § Inheritance contract:

```markdown
## `--copilot` mode

See `rules/lens-multi-model-review-pattern.md`.

Skill-specific synthesis lens: <one-line rationale, e.g. "PR diff + applicable patterns; security + correctness cross-check">.
```

And invoke this skill (`copilot-cli-bridge`) — they do NOT call the dispatcher directly. The skill is THE canonical wrapper; bypassing it duplicates the consent gate, the orchestrator-identity discipline, and the agreement-table synthesis logic.

This skill IS the cross-model verification mechanism — it does not need its own `--copilot` mode. Tier-target: **S** with `tier-exempt: [evals, templates]` per `skill-standards.md` § Pure-utility exemption:

- **Dim 4 (evals) exempt** — the dispatcher's behavior contract IS the eval shape; the JSON result envelope from `Invoke-CopilotMultiModel.ps1:97-122` (`New-DispatcherResult` helper) is the canonical contract this skill returns. The dispatcher ships its own evals (referenced in `.mad/reports/d7-council-verdict-iter3b-2026-05-02.md`); duplicating eval fixtures here would re-test the dispatcher, not the orchestration glue. The `Eval discipline` section below documents the fixtures that WOULD apply to this skill's orchestration glue (Task spawn, consent gate, agreement-table synthesis) for future Tier-S authoring; until then the dispatcher's coverage is the floor.
- **Dim 5 (templates) exempt** — output is non-prescriptive (a structured JSON envelope returned to the caller, not an artifact authored to disk). The cross-model agreement-table contract (Step 4) is inline in this SKILL.md as a literal template; consumers parse the table shape from the rule body rather than from a separate template file.

The remaining 4 dimensions are present in full: frontmatter (Dim 1), Best Practices section (Dim 2), Standards section (Dim 3), and **the cross-model contract IS the multi-pass mechanism** (Dim 6).

## Eval discipline

When this skill ships with evals (Dimension 4 of `skill-standards.md`), fixtures live at `.claude/skills/copilot-cli-bridge/evals/`:

- `evals/fixtures/clean-prompt.md` — synthetic review brief with no findings; expected agreement table empty; both models report zero findings.
- `evals/fixtures/critical-both-flag.md` — synthetic brief where both models will flag a CRITICAL SQL-injection pattern; expected one HARD BLOCK row.
- `evals/fixtures/disagreement.md` — synthetic brief where Opus flags MAJOR (auth missing) and GPT does not; expected one SHOULD-FIX (one-model signal) row.
- `evals/fixtures/escalated-critical.md` — synthetic brief where one model flags CRITICAL, the other doesn't; expected one MUST-FIX (escalate) row.
- `evals/fixtures/copilot-cli-missing.sh` — eval harness that unsets the Copilot CLI on PATH; expected `Mode: TaskFallback` and the canonical Context Gap line.
- `evals/fixtures/timeout-trigger.md` — eval harness that pins `timeout-seconds: 1` against a stalled dispatcher; expected `Mode: Timeout`.
- `evals/fixtures/concurrency-cap.md` — eval harness that drops 3 sentinels in `LockDir` before invocation; expected `Mode: ConcurrencyLimited`.
- `evals/fixtures/consent-refused.md` — eval harness that simulates user "no" on the consent prompt; expected `Mode: ConsentRefused` and `ConsentLog` entry.

The dispatcher (`Invoke-CopilotMultiModel.ps1`) ships its own evals (referenced in `.mad/reports/d7-council-verdict-iter3b-2026-05-02.md`); this skill's evals exercise the orchestration glue (Task spawn, consent gate, agreement table) on top of the dispatcher's existing test coverage.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| Orchestrator invokes `Invoke-CopilotMultiModel.ps1` directly via Bash | Violates `orchestrator-identity.md` Rule 1 ("never do the work yourself") | Spawn Task subagent; subagent runs the dispatcher |
| Skip the first-use-per-session consent gate | Violates `dangerous-operations-policy.md` § Cross-org A2A Bridge category | Always check session consent state; prompt on first use |
| Re-prompt for consent on every `--copilot` call | Annoys user; per `dangerous-operations-policy.md` § Idempotent retries: consent reuse within session is allowed | Persist consent in `.mad/scratch/copilot-cli-bridge-consent-<session-id>.json` |
| Treat `Mode: TaskFallback` as `Mode: CopilotCLI` for downstream synthesis | Skips the Context Gap line; misrepresents the rigor of the verification | Always emit the Context Gap line per `degradation-fallback-policy.md` Rule 3 |
| Read `OpusResultPath / GptResultPath` when `Mode != "CopilotCLI"` | Paths are `null` per M2 hardening (`Invoke-CopilotMultiModel.ps1:97-103`); attempted Read crashes | Check `Mode` before Read; rely on agreement table from subagent output |
| Lower `timeout-seconds` below 600 without empirical evidence | The 600s default is calibrated against ~3KB briefs (`Invoke-CopilotMultiModel.ps1:43-46`); 240s was insufficient pre-calibration | Keep default; only override when measuring local-CLI latency |
| Override the agreement-table decision rules at the call site | Inheriting skill MUST NOT redefine the dispatch mechanism, table shape, or hard-block rule per `lens-multi-model-review-pattern.md` § Inheritance contract | Propose a rule amendment via `/council-review`; do not fork |
| Use `--copilot` for routine implementation review | Cost not justified per `lens-multi-model-review-pattern.md` § When to use | Route to standard `pr-review` or `code-reviewer` without escalation |
| Spawn 4+ parallel `copilot-cli-bridge` calls | Concurrency cap (3) per `Invoke-CopilotMultiModel.ps1:48-50, 138-148`; 4th refused | Sequence calls; or wait for sentinel sweep (10-min stale window) |
| Skip the synthesis-lens input | Inheriting skill is required by `lens-multi-model-review-pattern.md` § Inheritance contract to specify the lens | Reject preflight; require `synthesis-lens` non-empty |
| Treat both-flag-MAJOR as auto-pass | Per Step 4 decision rules: both-flag-MAJOR is MUST-FIX, not pass | Apply the decision table literally |
| Use `subagent_type: code-investigator` for the Task spawn | code-investigator has read-only tools; it cannot run Bash to invoke the dispatcher | Use `general-purpose` per `lens-multi-model-review-pattern.md` § Mechanism |

## Best Practices

This skill inherits the kit-wide best practices from `.claude/rules/skill-standards.md` § Dimension 2:

- **FETCH BEFORE CITE** — read source files before claiming behavior; never reference a function or contract without opening it (per `rules/verification-protocol.md`). Dispatcher behavior is sourced from `Invoke-CopilotMultiModel.ps1:1-150`; cite file:line on all claims about timeouts, modes, lock semantics, fallback shape.
- **Anti-hallucination** — when both models flag zero findings, state "Cross-model agreement: no findings flagged by either model" explicitly. Do not pad the agreement table with reassurance prose.
- **Output Contract** — every entry in the agreement table carries: finding ID + severity tag + Opus state + GPT state + decision. The decision references the rule (HARD BLOCK / MUST-FIX escalate / SHOULD-FIX one-model / CONSIDER one-model).
- **Confidence floor** — HARD BLOCK requires both-flag-CRITICAL agreement (deterministic). MUST-FIX (escalated) requires one-model CRITICAL (high precision; the disagreement IS the signal per rule § Inheritance contract). SHOULD-FIX requires one-model MAJOR. CONSIDER requires one-model MINOR.
- **Existing-thread dedup** — when re-running cross-model dispatch on a brief that was already verified in the same session, suppress findings that the previous run produced unless the brief content changed (size + sha-1).
- **WorkIQ context** — the brief MAY reference a work item; if so, include the work-item ID in the dispatcher's prompt-file so both models have the grounding context.
- **Auto-fan-out** — N/A; this skill IS the fan-out mechanism (one-to-many model dispatch). Inheriting skills do their own fan-out at the finding level.

Skill-specific best practices:

- **Orchestrator-identity preserved**: the orchestrator never runs Bash to invoke the dispatcher; Task subagent does the work. The orchestrator's tool surface stays minimal (Task + Read).
- **Consent gate is first-use-per-session, not per-invocation**: aligns with `dangerous-operations-policy.md` § Idempotent retries.
- **Context Gap line is mandatory on fallback**: per `degradation-fallback-policy.md` Rule 3 and `lens-multi-model-review-pattern.md` § Fallback. The caller's final report MUST include it.
- **Decision rules are inviolable**: per `lens-multi-model-review-pattern.md` § Inheritance contract, inheriting skills cannot override the both-flag-CRITICAL hard-block rule. Rule amendments go through `/council-review`.
- **Same-model role-split fallback is weaker by design**: when Copilot CLI is missing, the same-model fallback shares blind spots and is strictly weaker than true cross-model. Always emit the Context Gap line; never silently equate the two paths.
- **Concurrency cap respected**: 3 parallel dispatches per machine per `Invoke-CopilotMultiModel.ps1:48-50`. Do not retry-spam — wait for sentinel sweep.
- **Default timeouts trusted**: 600s is the calibrated value (raised from 120s pre-2026-05 per `Invoke-CopilotMultiModel.ps1:43-46`). Do not override without empirical evidence.
- **No data exfiltration without consent**: per the auto-mode rule "Avoid data exfiltration" — Copilot CLI dispatch is exfiltration-shaped (third-party model endpoint). The first-use consent gate is non-negotiable.

## Standards

This skill inherits these load-bearing rules:
- `.claude/rules/non-negotiable-rules.md` — verb-bound permission fences (no `run_in_background: true`; no destructive ops without consent)
- `.claude/rules/verification-protocol.md` — FETCH BEFORE CITE (cite `Invoke-CopilotMultiModel.ps1` file:line for every behavioral claim)
- `.claude/rules/orchestrator-identity.md` Rule 1 — "ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF"; the basis for the Task-subagent-spawn shape
- `.claude/rules/lens-multi-model-review-pattern.md` — the substrate this skill implements; this skill is the canonical wrapper for `--copilot` mode
- `.claude/rules/dangerous-operations-policy.md` § Cross-org A2A Bridge — first-use-per-session consent gate
- `.claude/rules/degradation-fallback-policy.md` Rule 3 — Context Gap reporting on degraded modes
- `.claude/rules/skill-standards.md` — 6-dimension compliance (target: Tier S)

Naming:
- The skill name `copilot-cli-bridge` reflects the kit's choice to wrap the existing `Invoke-CopilotMultiModel.ps1` dispatcher; the dispatcher's name is preserved (vendored from Shayon Gupta's LENS-Common PR #5138039 per `lens-multi-model-review-pattern.md` § Reference).
- The result envelope field names (`Mode`, `OpusResultPath`, `GptResultPath`, `ModelsRun`, `ContextGap`, `TimeoutSecondsUsed`) mirror the dispatcher's `New-DispatcherResult` helper output exactly per `Invoke-CopilotMultiModel.ps1:97-122`.
- The agreement table column names (`Finding | Opus | GPT | Decision`) match `lens-multi-model-review-pattern.md` § Output verbatim.

## References

- `m-main/src/services/copilot.ts:7-83` — Copilot service IPC client (renderer side); structural reference for the upstream Copilot integration shape. The dispatcher this skill wraps lives at the kit's PowerShell layer; the m-main file is the IPC-layer counterpart in the Electron app context.
- `m-main/.copilot/mcp-config.json:2-9` — canonical mcpServers shape verified against the upstream `.copilot/` config (`playwright` MCP via `npx`).
- `.claude/scripts/Invoke-CopilotMultiModel.ps1:1-150` — the dispatcher this skill wraps; param block at lines 71-89; result helper at 97-122; preflight at 124-127; output dir resolution at 129-136; concurrency cap at 138-150.
- `.claude/scripts/Invoke-CopilotMultiModel.ps1:11-21` — M1/M2/M3 hardening rationale (cited in `Confidence floor` and `null paths` discussions above).
- `.claude/rules/lens-multi-model-review-pattern.md` — the rule body; § Mechanism (lines 33-53), § Inheritance contract (lines 63-91), § Output (lines 93-112), § Fallback (lines 114-130).
- `.claude/rules/orchestrator-identity.md` Rule 1 — "ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF"; basis for the Task-subagent-spawn shape.
- `.claude/rules/dangerous-operations-policy.md` § Cross-org A2A Bridge — first-use-per-session consent gate.
- `.claude/rules/degradation-fallback-policy.md` Rule 3 — Context Gap reporting on degraded modes.
- `.mad/reports/d7-council-verdict-iter3b-2026-05-02.md` M1/M2/M3 — the council verdict that hardened the dispatcher; this skill inherits that hardening.
- `.mad/reports/d8-council-verdict-iter3b2-matrix-2026-05-02.md` MX2 — the verdict pinning the multi-model mechanism.
