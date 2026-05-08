# Implementability Gate (Step 7.1)

This is the reference doc for /mad-spec Step 7.1. It defines the 5 sub-checks (Vision/Newspaper/3-Nouns/Implementation-Squeeze/Concept-Density) and the **lane charters** for parallel fan-out when FR count >= 20.

**Why this exists:** in the (D) attempt of the canonical pipeline, /mad-spec spent ~7-8 minutes running these 5 checks SEQUENTIALLY across 45 FRs inside a single subagent context. That's the second-largest wall-clock contributor. The fix is to fan out to 3 parallel `code-implementer` subagents, each handling ~15 FRs.

## When to fan out (decision rule)

- **FR count < 20**: run inline serial. The per-FR loop is fast at small scale (~3-4 min for 15 FRs).
- **FR count >= 20**: orchestrator dispatches 3 parallel subagents in a SINGLE message with 3 Task blocks. Wall-clock: ~3 min total vs ~8 min serial. A 2.5-3x speedup that's invisible to quality.

The skill body Step 7.1 detects FR count via `Grep -c "^\\*\\*FR-" <FEATURE_DIR>/spec.md` and chooses the path.

## The 5 checks (run in every lane)

For each FR assigned to the lane, run these 5 checks. Each check is binary PASS/FAIL with a remediation string on FAIL.

### Check 1 — Vision/Contract Test

Read the FR's **Logical Proof** bullet. Does it name a specific file, endpoint, command, or test artifact?
- PASS: "run `curl GET /api/v1/cases` and check for 200" / "check `Test-Path <channel-dir>/retros/<run_id>.json`"
- FAIL: "verify behavior" / "ensure correct output" / "system works as expected"
- Remediation on FAIL: edit the FR's Logical Proof to name a concrete artifact (file path, endpoint, command, expected output)

### Check 2 — Newspaper Test

For the FR, answer: "What file or output would I look at to confirm this works?"
- PASS: answer names a specific artifact (same shape as Check 1; this is the inverse phrasing)
- FAIL: answer is "it depends on how we build it" or refers to "the implementation"
- Remediation on FAIL: edit the FR's Logical Proof to specify the concrete artifact path

### Check 3 — 3-Nouns Test (per user story, not per FR)

For each user story (US-N) attached to the FR's domain, count concrete nouns (endpoint paths, database tables, file names, UI components, CLI commands, log entries).
- PASS: >= 3 concrete nouns
- FAIL: < 3 concrete nouns
- Remediation on FAIL: add concrete artifacts to the user story's Acceptance Scenarios

(Each FR doesn't need its own 3-nouns check — it's a user-story property. But the lane reports the user-story check for any FR whose user story fails.)

### Check 4 — Implementation Squeeze

For the FR, answer: "If an agent has only Read, Write, Bash, Grep — what is the FIRST command it runs to verify this FR?"
- PASS: a concrete command (`Test-Path X`, `curl Y`, `grep Z`, `pwsh script.ps1`)
- FAIL: cannot answer / requires inferring implementation
- Remediation on FAIL: add the verification command to the FR's Logical Proof

### Check 5 — Concept Density (warn, not block)

Across the FR + its user story, count new coined compound terms (CamelCase concepts not in standard vocabulary: e.g., "NLSpec", "GoalGate", "SatisfactionScore").
- WARN if > 5 new terms in the FR's scope AND any term is undefined in terms of existing primitives
- This is advisory only. It does NOT BLOCK the gate.

## Lane charters (parallel fan-out)

When FR count >= 20, the orchestrator dispatches 3 parallel `code-implementer` subagents. Each gets a disjoint partition of the FR list.

### Standard partition (FR-prefix-based, balanced)

Sort FRs by FR ID. Partition into 3 contiguous segments of as-equal-as-possible size:

- **Lane A**: first ~33% of sorted FR list
- **Lane B**: middle ~33%
- **Lane C**: last ~33%

For 45 FRs: Lane A = FRs 1-15, Lane B = FRs 16-30, Lane C = FRs 31-45.

### Domain-aware partition (preferred when FR prefixes cluster)

If FRs cluster heavily by domain prefix (e.g. 10 CORE FRs together, 4 ISOLATION, 3 COST), partition to keep domain prefixes together so each lane can spot in-domain consistency issues:

- **Lane A — Core / Identity / Isolation domains** (~15 FRs)
- **Lane B — Cost / Lifecycle / Reliability domains** (~15 FRs)
- **Lane C — Integration / External-system domains** (~15 FRs)

The exact partition is captured in the dispatch prompt; the lanes themselves don't need to know each other's partition.

## Subagent prompt shape (orchestrator-side)

```
You are running the implementability gate for Lane <X> against <FEATURE_DIR>/spec.md.

Your FR list (disjoint from other lanes):
- FR-CORE-001
- FR-CORE-002
- ...
- FR-LIFECYCLE-001

For EACH FR in your list, run all 5 checks defined in
.claude/skills/mad-spec/references/implementability-gate.md.

For each check:
- Mark PASS or FAIL
- On FAIL: emit the FR ID, the check name, the failing text, and the remediation

Anti-pattern guard: Enumerate exhaustively. No Top-N capping. Every FR in your
list must be classified. State 'no findings' explicitly if all checks pass for
all FRs in your lane.

Report at end:
- FRs PASSED (full list)
- FRs FAILED (with check name + remediation per failure)
- Lane completion time

Do NOT edit the spec yourself. Lead synthesizes findings and applies edits.
```

## Synthesis rubric (orchestrator-side, after lanes return)

The orchestrator (lead) collects all 3 lane reports and synthesizes:

1. **Union the FAIL findings** from all 3 lanes.
2. **Apply remediations**: for each FAIL, edit the affected FR (single-FR edit, not whole-spec re-author). The remediation strings from each lane are line-specific; targeted Edit tool calls are sufficient.
3. **Re-run only the failed FRs** through the 5 checks (now inline, since the count of failed FRs after remediation should be small). Confirm PASS.
4. **Concept Density warnings**: aggregate across lanes; if total > 5, present to user as a non-blocking note.
5. **Gate result**: PASS only if all FRs in all 3 lanes now PASS Checks 1, 2, 3, 4. Concept Density (Check 5) is informational.

Lane Context Gaps (e.g. a lane reported "FR-CORE-005 is not parseable") are surfaced in the orchestrator's Self-Review section.

## Validation (smoke check this lane mechanism)

The first time the parallel path is exercised, the orchestrator should:
- Note the FR count before dispatch
- Note wall-clock start before dispatch
- Confirm 3 Task blocks are in a SINGLE message (not separate messages — `detect-parallel-miss.js` will warn otherwise)
- Note wall-clock end after the slowest lane returns
- Total target: < 5 min for 45 FRs (vs ~8 min serial baseline)

## Inline-fallback path (FR count < 20)

For small specs, run the 5 checks serially in the skill body. The per-FR loop is fast enough at this scale and adding fan-out coordination overhead would slow it down (~30s-1min of fan-out tax for ~3 min of saving).

The serial path is identical in content to the lane charter — just with a single executor.
