# Implementation Plan: /council-review

Target: MAD.Council Phase 2 — Council Review per `mad.council.a2a.md` §12. The most complex skill; ~40h estimated effort.

## Dependencies

| Dependency | Where | Status |
|---|---|---|
| `scripts/atomic-write.ps1` | iter 11 scripts/ | ⏸ |
| `scripts/channel-helpers.ps1` | iter 11 | ⏸ |
| `scripts/literal-phrase-scan.ps1` (shared) | iter 11 | ⏸ |
| `MAD/agents/advocate/agent.md` (role sub-agent contract) | iter 13 | ⏸ |
| `MAD/agents/skeptic/agent.md` | iter 13 | ⏸ |
| `MAD/agents/architect/agent.md` | iter 13 | ⏸ |
| `scripts/yagni-filter.ps1` (grep-and-demote logic) | iter 11 | ⏸ |
| `scripts/pattern-verify.ps1` (pattern-improvement detector) | iter 11 | ⏸ |
| `scripts/verdict-compute.ps1` (severity → verdict threshold logic + mechanical ESCALATE) | iter 11 | ⏸ |

## Implementation steps

### 1. Parse arguments

- `<thread-id>` required.
- Optional: `--roles`, `--mode`, `--ensemble`, `--alias-set`.
- Validate `--roles` values (enum).
- Validate `--mode` values (`auto` or `propose`).

### 2. Preflight

- Verify membership.
- Read thread.json; check status=active.
- Count messages; if >50, trigger batch-gate.

### 3. Resolve run_id

- Inherit from thread's last message (ties verdict to lineage).

### 4. Build role briefs

- Per-role prompt template loads from `MAD/agents/<role>/agent.md` (iter 13 artifacts).
- Substitute context: thread path, messages list, spec/plan references, attachment list.
- Include strict JSON output schema.

### 5. Spawn roles in parallel (synchronous Task calls)

- Build a single message with N Task blocks (N = number of roles from `--roles`, default 3).
- Each Task gets its role's brief + 4-minute internal timeout.
- Wait for all to return (or time out).
- If `--ensemble`: Skeptic expands to 3 Task calls with different model IDs.
- NEVER use `run_in_background: true` per project CLAUDE.md + CHK-011 (resolved).

### 6. Collect outputs

- Each role returns JSON. Parse.
- Malformed → mark invalid_output; 0 findings.
- Role timed out → completed=false, timed_out=true.
- Apply Rule-1 scan on finding text (defense-in-depth).

### 7. Apply YAGNI filter

- For each Skeptic finding of shape "add feature X / abstraction Y":
  - Use `scripts/yagni-filter.ps1` — greps codebase + thread for referenced symbol.
  - 0 hits → demote severity; annotate.
  - Preserve finding (don't delete).

### 8. Apply pattern-verification filter

- For each finding citing "deviation from pattern X":
  - Use `scripts/pattern-verify.ps1` — greps pattern occurrences; scores whether deviation is improvement.
  - Annotate; potentially demote.

### 9. Dedupe + sort findings

- Merge findings with same `file:line` + same severity (keep highest confidence).
- Sort by severity DESC, then confidence DESC.

### 10. Compute verdict

- Call `scripts/verdict-compute.ps1` with findings + role_confidence values.
- Returns: verdict, verdict_reasoning, verdict_confidence, suggested_next_action.
- Mechanical ESCALATE triggers per SKILL §Step 8.

### 11. Write verdict.json

- Atomic write.
- Include all fields per schema.

### 12. Post resolve message

- Invoke `/council-post` with resolve type + verdict summary.
- Inherits verdict's run_id.

### 13. Emit output

- Render success block per SKILL §Step 11.
- If any role timed out, surface prominently.

## Ensemble-specific flow

When `--ensemble`:

- Skeptic role spawns 3 instances via Copilot CLI: gpt-5.5 + gpt-5.3-codex + claude-opus-4.7 (vendor-diverse).
- Each returns JSON findings + role_confidence.
- Consensus validator: spawns 1 more Task call (Claude Opus) with all 3 outputs + consensus rubric per `wiki/patterns/multi-model-ensemble.md` §5.6.
- Validator returns: findings aggregated + consensus-derived confidence.

If validator times out: fall back to 2/3 majority. If no majority: safe default → findings classified `valid_low_priority`.

## Rollback

| Failure point | Rollback |
|---|---|
| Step 5 (role spawn) — all roles fail | No verdict; `rc=1` with explicit "all roles failed" |
| Step 5 — some roles fail | Proceed with survivors; verdict has `completed: false` flags |
| Step 11 (verdict.json write) | `rc=4`; verdict not persisted; thread unchanged |
| Step 12 (post resolve) | `rc=1` with warning; verdict.json persisted but thread not auto-resolved. User or next review picks up |

## Error messages

| Condition | Message |
|---|---|
| Thread not active | `"Cannot review <status> thread. Council operates on active threads only."` |
| Thread >50 messages | preview + continue/last-20/cancel prompt |
| All roles fail | `"All 3 roles failed or timed out. Retry with /council-review <tid>. If persistent, consider --roles skeptic for fast triage."` |
| Validator times out (ensemble) | `"Ensemble validator timed out; falling back to 2/3 majority."` |

## Test coverage targets

Per `tests.md`:

- All 4 verdict types (FIX/ACCEPT/ESCALATE/INVESTIGATE) reachable via tests.
- All mechanical ESCALATE triggers exercised.
- YAGNI demotion verified.
- Pattern-verification annotation verified.
- Ensemble mode with 3/3 / 2/3 / all-disagree covered.
- Role timeout handling covered.
- Batch-gate on long threads covered.
- Confidence threshold cases (0.85, 0.5) at boundaries.
- All 6 rc codes reachable.

Coverage target: **95%+ branch**.

## Estimated effort

| Step | Hours |
|---|---|
| Arg parsing + validation | 2 |
| Preflight + batch-gate | 2 |
| Role brief composition | 3 |
| Parallel spawn orchestration | 4 |
| Output parsing + Rule-1 scan | 3 |
| YAGNI filter integration | 3 |
| Pattern-verification filter integration | 3 |
| Verdict computation logic | 6 |
| Ensemble mode + validator | 5 |
| verdict.json write | 1 |
| Resolve-message post | 1 |
| Output rendering | 2 |
| Tests (extensive) | 12 |
| **Total** | **~47 hours (~6 working days)** |

## Risks

| Risk | Mitigation |
|---|---|
| Claude Code 5-min stream abort during long role executions | 4-min per-role timeout; batch-gate on long threads (prefer last-20) |
| Role correlation when all 3 use same model | Ensemble mode forces different model families; without ensemble, warn that single-model may have aligned biases |
| Confidence scores poorly calibrated across models | Use confidence alongside mechanical thresholds, not as sole decision input |
| YAGNI false-negatives (caller exists but grep misses it) | Annotate uncertainty ("grep did not find callers — may exist in unscanned paths"); don't demote to LOW — demote to MEDIUM-with-caveat |
| Pattern-verify over-applies "improvement" note | Require deviation to appear in ≥2 locations to be considered pattern-worthy |
| Role timeout exhausts quota without useful output | `invalid_output` flag separates "didn't respond" from "responded with nothing" |

## Forward-links

- `evals/fixtures/council-review-clean-thread/` — ACCEPT verdict path.
- `evals/fixtures/council-review-critical-finding/` — FIX verdict path.
- `evals/fixtures/council-review-3-high-findings/` — FIX via count threshold.
- `evals/fixtures/council-review-all-low-confidence/` — ESCALATE via mechanical trigger.
- `evals/fixtures/council-review-3-role-disagreement/` — ESCALATE via mechanical trigger.
- `evals/fixtures/council-review-role-timeout/` — 2/3 roles completed.
- `evals/fixtures/council-review-yagni-demotions/` — YAGNI filter effect.
- `evals/fixtures/council-review-ensemble-consensus/` — 3/3 ensemble consensus.
- `evals/fixtures/council-review-ensemble-disagree/` — all-disagree → ESCALATE.
- `evals/fixtures/council-review-long-thread-batch-gate/` — 55-message thread.
- `evals/layer-3-e2e/multi-role-review.test.md`.
- `evals/layer-4-adversarial/verdict-manipulation.test.md`.
