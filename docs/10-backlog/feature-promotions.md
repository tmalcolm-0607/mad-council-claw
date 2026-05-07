# Feature promotions (rules-without-hooks)

Per `rules-without-hooks-audit.md` discipline (from `[A:rules-without-hooks-audit.md]` in the prior session): when a documented rule recurs as a correction ≥3 times, it's a promotion candidate — it should become a PreToolUse hook (or otherwise mechanically enforced) so future instances don't re-break it.

Per memory entry `feedback_documented_rules_need_hooks.md`: "Documented rules without hooks recur."

## Schema

```
| Rule path | Promotion target | # times observed | Source observations (wave/lane) | Confidence | Blocking factors |
```

## Entries

| Rule path | Promotion target | # times observed | Source observations | Confidence | Blocking |
|---|---|---|---|---|---|
| `.claude/rules/no-top-n-capping.md` | already a PreToolUse:Task hook (`detect-top-n-capping.js`) — but the audit found multiple subagent prompts still missing the sentinel | hook exists; recurrence is in human-authored prompts that bypass the hook by being authored in a session-tool that doesn't run hooks | wave-001 across all lanes — every lane subagent prompt had to include the sentinel verbatim per CLAUDE.md | HIGH | extend hook to detect prompts authored in `.mad/scratch/`, not just Task spawns |
| `.claude/rules/no-silent-deferrals.md` | PostToolUse hook (`content-scan-deferrals.js`) exists; but kept being violated in iter-41 collab-engine session | hook exists but the override `--force-raw` and self-trigger exemptions can mask hits | wave-001 lane-d (canonical-e v-next-release deferral list enumerated; some were sanctioned, others were silent) | HIGH | hook needs stricter exemption-list and clearer exempt-paths doc |
| `.claude/rules/canonical-skill-only.md` | PreToolUse:Write\|Edit hook (`validate-mad-pipeline.js`) exists | hook exists; iter-41 closed the Edit loophole | wave-001 lane-d (kit inventory confirmed hook coverage) | HIGH (hook live) | none; this one is closed |
| `.claude/rules/canonical-artifact-frontmatter.md` | PostToolUse hook (`enforce-skill-canonical-marker.js`) exists | hook exists | wave-001 lane-d kit inventory | HIGH (hook live) | none; this one is closed |
| `.claude/rules/scope-discipline.md` | NO hook today — recurring violation pattern: items marked scope-excluded without backlog entry | the iter-41 spiral was driven by silent scope-drift; user-mandated fix was to add backlog rows + commit-time enforcement | wave-001 lane-d + memory `feedback_create_skill_when_pitfalls_repeat.md` | HIGH | hook needed: PreToolUse:Bash on `git commit` — block if any new file under specs/ lacks a backlog row OR a `scope-discipline` rationale in the commit message |
| `.claude/rules/loop-cadence-discipline.md` | NO hook today — would catch `delaySeconds` in forbidden zone (280-1199s) | recurring drift: "let's check every 10 minutes" pattern lands in forbidden zone | wave-001 lane-zero implicit (cron cadence) + memory `feedback_skill_speed_expectations.md` | MEDIUM | hook needed: PreToolUse:ScheduleWakeup that rejects forbidden-zone delays; SDK extension required (no hook surface today) — backlog as feature, not rule |
| `.claude/rules/autonomous-loop-discipline.md` | NO hook today — orchestrator-discipline rule (no mechanical surface) | drift: orchestrator pauses for permission between iters | session 6ac2f083 (in CLAUDE.md) | MEDIUM | not hook-able; rule-only enforcement; codify in cron prompt template |
| `.claude/rules/loop-stop-language-discipline.md` | NO hook today — output-content rule | drift: "Final state" / "loop complete" language used mid-loop | session 6ac2f083 | MEDIUM | hook needed: PostToolUse on assistant-final-message that scans for forbidden phrasings; SDK has no such hook today |
| `.claude/rules/no-invented-constraints.md` | NO hook today | drift: invented "5M-token soft cap" that user never set | session 249a59a7 | MEDIUM | hook needed: scan summaries for budget/cap framing; not currently hook-able |
| `.claude/rules/orchestration.md` | PreToolUse hook (`enforce-orchestration.js`) exists | hook exists; blocks main-thread Read on code files | wave-001 lane-d kit inventory | HIGH (hook live) | none; this one is closed |
| `.claude/rules/verification-protocol.md` | NO hook today — "FETCH BEFORE CITE" + "ACTUAL BEFORE PRESENT" rules | drift: claimed test results without running them; cited files without reading | memory `feedback_no_speculation.md` | MEDIUM | hook concept: scan assistant message for "tests pass" / "build succeeds" / "as noted in `<file>`" without preceding Bash dotnet test / Read of `<file>` in prior turns; not currently hook-able |
| `.claude/rules/dangerous-operations-policy.md` | partial PreToolUse hooks (`pre-bash-validate.js` blocks some destructive git ops) | recurring drift: `az` / `gh` destructive ops not always gated | session 6ac2f083 + multiple LENS deploy sessions | HIGH | extend `pre-bash-validate.js` to also block `az group delete`, `az resource delete`, `gh repo delete` without explicit consent |

## Top-5 from prior session (per `[A:rules-without-hooks-audit.md]`)

> _Per session 6ac2f083 + 249a59a7 + collab-engine iter-1-41 retro_

1. **`scope-discipline.md`** — 12+ recurrence; HIGH promotion priority; commit-time hook needed
2. **`no-silent-deferrals.md`** — 8+ recurrence; HIGH promotion priority; existing hook needs exemption-list tightening
3. **`loop-stop-language-discipline.md`** — 6+ recurrence (mostly mid-loop); MEDIUM; SDK gap (no assistant-message hook surface)
4. **`no-invented-constraints.md`** — 4+ recurrence; MEDIUM; SDK gap
5. **`verification-protocol.md` ACTUAL BEFORE PRESENT** — recurring across LENS deploy sessions; HIGH-MEDIUM; tooling gap (would need cross-message-history scan)

## Wave-2 / Lane D update

Per Lane D wave-1 finding "5 anti-pattern hooks are LOAD-BEARING" — these promotion candidates extend that list. The five top candidates above represent the rules most likely to recur if the engine is rebuilt without re-applying. **F-22..F-X engine telemetry tests should explicitly exercise each rule's triggering condition** to catch regression.

## Wave-2 / Lane C update — Copilot CLI design review (gpt-5.5 single-model, Opus timed out)

Source: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md`. 8 NEW F-NNN candidates promoted to feature catalog (HIGH confidence, single-model only — Opus timeout means cross-model agreement table is empty; promote with manual gate per `lens-multi-model-review-pattern.md` fallback section).

| F-NNN | Title | Target milestone | Rationale (wave-1 source) | Confidence |
|---|---|---|---|---|
| F-127 | foundation-governance-kernel | M0 (was M2) | Critical: M0/M1 ship executable surfaces before M2 governance reachable; ungovernable-by-construction. | HIGH (single-model) |
| F-128 | per-agent-identity-bootstrap | M0 (was implicit M2) | Critical: identity chain needed from first turn; audit/cost/OAuth/permissions/replay all depend. CE FR-IDENTITY-001 + Agent365 + CP. | HIGH (single-model) |
| F-129 | oauth-refresh-singleflight-lock | M2 | Critical: matches OpenClaw F3 (refresh-token reuse can revoke entire provider account). | HIGH (single-model) |
| F-130 | tool-invocation-proof-gate | M2 | Critical: matches Devin lessons (#1 failure mode = hallucinated tool invocation); existing F-047/F-058..061 lack pre-execution proof. | HIGH (single-model) |
| F-131 | fanout-budget-governor | M2 | Critical: matches Anthropic multi-agent ~10x token cost; M10 ships council too late if K-origin agent-team patterns appear in foundation loops. | HIGH (single-model) |
| F-132 | parent-child-supervision-locks | M2/M3 | Major: matches OpenClaw F4 (detached background processes); needs OS-level flock/LockFileEx + heartbeat lease + orphan reaper. | HIGH (single-model) |
| F-133 | real-agent-filesystem-isolation | M2 | Major: matches Lane C L1 (per-agent isolation must be filesystem-real, not synthetic). | HIGH (single-model) |
| F-134 | skill-supply-chain-attestation | M7 with M0 gate | Major: 70 inherited skills have no manifest lockfile / content hash / signature gate today. | HIGH (single-model) |

## Wave-3 / Lane B update — Copilot CLI design review retry (Opus succeeded, cross-model populated)

Source: `docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md` § Wave-3 retry resolution + § Cross-model agreement table.

Cross-model verdict on each wave-2 F-NNN promotion + 3 NEW F-NNN candidates surfaced by Opus only:

| F-NNN | Title | Wave-2 conf | Wave-3 cross-model verdict | Notes |
|---|---|---|---|---|
| F-127 | foundation-governance-kernel | HIGH (gpt-5.5) | HARD BLOCK (Opus C1 + gpt-5.5 C1 both Critical) | Both models flag governance retrofit as a foundation-order blocker. M0/M1 must not ship without F-014/F-015/F-019/F-022/F-088 forward-moved. |
| F-128 | per-agent-identity-bootstrap | HIGH (gpt-5.5) | HARD BLOCK (Opus M4 + gpt-5.5 C2; severity escalates to Critical) | Both flag; gpt-5.5 escalates to Critical. CE FR-IDENTITY-001 + OpenClaw F1 cost-attribution drift = root convergence. |
| F-129 | oauth-refresh-singleflight-lock | HIGH (gpt-5.5) | HARD BLOCK (Opus M3 + gpt-5.5 C3; severity escalates to Critical) | Both flag OpenClaw F3 root cause. Spec F-079 token refresh must require single-flight per identity. |
| F-130 | tool-invocation-proof-gate | HIGH (gpt-5.5) | HARD BLOCK (Opus C3 + gpt-5.5 C4 both Critical) | Both models flag Devin #1 failure mode. F-022/F-058/F-125 are rate/cardinality, not schema-validation. New error code `ERR_TOOL_HALLUCINATED`. |
| F-131 | fanout-budget-governor | HIGH (gpt-5.5) | HARD BLOCK (Opus M2 + gpt-5.5 C5; severity escalates to Critical) | Both flag Anthropic 10x token cost; both place at M2. Tie F-126 context-budget to F-018 cost ledger. |
| F-132 | parent-child-supervision-locks | HIGH (gpt-5.5) | MUST-FIX (Opus M5 + gpt-5.5 M-E both Major) | Both flag OpenClaw F4. OS-level flock/LockFileEx + heartbeat lease. |
| F-133 | real-agent-filesystem-isolation | HIGH (gpt-5.5) | **MEDIUM** (gpt-5.5 only — Opus folds into supervision-lock C2/M5) | Demoted to MEDIUM cross-model. Wave-4 third-model corroboration recommended. |
| F-134 | skill-supply-chain-attestation | HIGH (gpt-5.5) | HARD BLOCK (Opus C4 + gpt-5.5 M-G; severity escalates to Critical) | Both flag; Opus escalates to Critical. M0 gate (NOT M7-only). MSEC bootcamp parallel + 70 inherited skills. |
| **F-135** | mcp-oauth-2.1-tls-pin | n/a (new) | MEDIUM (Opus G5 + gpt-5.5 G8 — both flag gap; F-NNN shape divergent) | New cross-model gap. Either fold into F-122 hardening or new F-NNN. |
| **F-136** | agent-manifest-export | n/a (new) | LOW (Opus G7 only) | Opus-only; promote at LOW pending wave-4 corroboration. |
| **F-137** | supervisor-status-stream | n/a (new) | LOW (Opus G9 only) | Opus-only; F-024 heartbeat doesn't surface degraded states to UX. |
