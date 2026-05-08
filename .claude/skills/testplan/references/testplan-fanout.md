# Testplan parallel fan-out lane charters

When `Compute-FrCount.ps1` returns `decision: "parallel"` (FR count >= threshold, default 20), use these lane charters for the 3 parallel subagent dispatch.

This file is the lane-charter rubric referenced from `.claude/skills/testplan/SKILL.md` Phase 1 Step 1.0a. Read it BEFORE composing subagent prompts.

---

## Source pathology this fixes

Lane C finding #5 (Per-FR / per-test-case serial gates):
- A 50-FR spec produces ~200 inline LLM emissions in a single subagent (50 FRs × 4 sub-checks per FR).
- No fan-out gate exists in the legacy single-subagent flow.
- Wall-clock cost: 41.7-min p90, dominated by serial per-FR scenario authoring.

Lane C finding #4 (Single-subagent monoliths):
- `/mad-spec` Step 7.5 auto-fires `/testplan` as a single subagent.
- That single subagent generates all 80+ test cases inline.
- Splitting into 3 lanes amortizes both prompt overhead and per-FR authoring cost.

---

## Lane partition rule

Round-robin partition of FRs across 3 lanes by index:
- Lane 1 receives FRs at index `0, 3, 6, 9, ...` (every third starting at 0).
- Lane 2 receives FRs at index `1, 4, 7, 10, ...` (every third starting at 1).
- Lane 3 receives FRs at index `2, 5, 8, 11, ...` (every third starting at 2).

`Compute-FrCount.ps1` returns the partition in its JSON output (`lanes[].fr_partition[]` arrays). Do NOT recompute the partition in the orchestrator — use the script output verbatim.

Round-robin (vs sequential N/3 chunks) reduces cross-lane straggler skew when FRs at the start of the spec tend to be more complex than FRs at the end (or vice versa).

---

## Dispatch shape

Single orchestrator message containing 3 Task tool blocks (NEVER `run_in_background: true` per non-negotiable rules — confirmed bug class: hangs + empty outputs).

Each Task block uses `subagent_type: code-implementer` (writes test plan files). Each subagent prompt contains:

1. The literal exhaustive-enumeration sentinel: "Enumerate exhaustively. No Top-N capping. Every item classified and acted upon. State 'no findings' explicitly when a category is empty."
2. Path to the Phase 0.6 context bundle (`.mad/scratch/testplan-context-<run-id>.md`).
3. The lane's FR partition (verbatim from Compute-FrCount JSON).
4. The lane charter (one of the three sections below).
5. Required output format (JSON with `plans_created: [...]`, `fr_coverage: { fr_id: plan_path, ... }`, `count: N`).

Use `.claude/scripts/Get-SubagentPromptBoilerplate.ps1` to compose the standard prompt prefix.

---

## Lane charters

### Lane 1 — FR partition 1 (round-robin index 0, 3, 6, ...)

**Scope**: Generate test plan(s) for each FR in your partition. Read the Phase 0.6 bundle once for context (spec.md, projects.json, prior artifacts, deferral inheritance source).

**For each FR in your partition**:

1. Classify the FR's test domain:
   - API endpoint (HTTP verb + route in FR text) → `Template ApiBehavioral`
   - UI flow (page reference, frontend route, user interaction) → `Template FrontendPlaywright`
   - Spec scenario (acceptance criteria language, no specific endpoint/route) → `Template SpecDerived`
   - Cross-project (FR mentions 2+ projects) → `Template CrossProject`
   - Behavioral concern (idempotency, ETag, tenant isolation, observability, state machine) → `Template Behavioral`

2. Invoke the scaffold script:
   ```powershell
   powershell.exe -NoProfile -File .claude/scripts/Init-TestPlanScaffold.ps1 `
     -TargetPath "<plan-path-from-projects.json-test_plans_dir>" `
     -PlanId "<derived-plan-id>" `
     -Project "<project-name>" `
     -Template <selected-template> `
     -WorkItemId "<work-item-id from bundle>"
   ```

3. Fill variant content via Edit:
   - **Prerequisites** — concrete prerequisites (env URLs, auth tokens, seed data) drawn from projects.json.
   - **Test Cases** — one test case per acceptance scenario in the FR. MANDATORY persistence-verify GET after every mutation per FR-ASSERT-001/002/003 (see SKILL.md § The Behavioral Assertion Standard).
   - **Assertions** — concrete checkbox list tied to the FR's acceptance criteria.
   - **Pass/Fail History** — leave the UNTESTED row from the scaffold; do NOT pre-populate.

4. Preserve any deferral keywords from the source FR verbatim (per `rules/no-silent-deferrals.md` asymmetry — adding deferrals OK with user consent; removing deferrals NOT allowed). The deferral-inheritance sentinel emitted by the scaffold protects the file from `content-scan-deferrals.js` flagging.

**Output**: JSON object with:
- `plans_created`: array of absolute plan file paths
- `fr_coverage`: object mapping each FR ID in your partition to its plan path
- `count`: integer (length of plans_created)
- `partition_processed`: array of FR IDs processed (must equal the input partition)

If a category produces no findings (e.g., your partition contains zero behavioral-concern FRs), state that explicitly in the output (`behavioral_count: 0` with rationale "no FRs in partition matched behavioral classifier").

---

### Lane 2 — FR partition 2 (round-robin index 1, 4, 7, ...)

**Scope, classification rules, scaffold invocation, fill rules, deferral preservation, output format**: identical to Lane 1.

The only difference is the FR partition you receive. Process exhaustively — every FR in your partition produces at least one plan, or an explicit "no plan needed" rationale (e.g., FR is meta-documentation with no behavioral surface).

---

### Lane 3 — FR partition 3 (round-robin index 2, 5, 8, ...)

**Scope, classification rules, scaffold invocation, fill rules, deferral preservation, output format**: identical to Lane 1.

Same partition-only difference as Lane 2.

---

## Synthesis (orchestrator-side)

After all 3 lanes complete:

1. **Concatenate `plans_created` arrays** across the 3 lane outputs into a single list.
2. **Merge `fr_coverage` objects** into a single map; verify no FR ID is mapped by more than one lane (lane partitions are disjoint by construction; duplicate would indicate a bug).
3. **Compute partition union**: every FR ID in the source spec must appear in exactly one lane's `partition_processed`. If any FR is missing, the partition was malformed — re-run `Compute-FrCount.ps1` and re-dispatch.
4. **Run Phase 3.5 coverage verification** (`Verify-Coverage.ps1`) across all generated plan paths against the source spec. Surface orphan FRs to the user; do NOT silently defer.
5. **If any FR has no plan** (Verify-Coverage exit 2): re-issue a follow-up dispatch to a single `code-implementer` lane handling only the orphan FRs. Do NOT batch the orphan-recovery into a 3-lane fan-out — the volume is small and serial is faster at low N.

---

## Failure modes and recovery

| Failure | Detection | Recovery |
|---|---|---|
| One lane returns truncated output (>30K token cap per non-negotiable rules) | Subagent response ends mid-array | Re-spawn that lane only, instructing it to chunk responses ≤30K segments per CLAUDE.md |
| One lane's output references plan paths the orchestrator can't see on disk | Post-spawn `Test-Path` returns false | Re-spawn that lane; the previous spawn likely failed mid-write |
| `partition_processed` count mismatches lane's input partition | Length comparison | Re-spawn that lane with explicit instruction to enumerate exhaustively (Top-N capping antipattern) |
| Two lanes claim coverage of the same FR ID | `fr_coverage` merge collision | Bug in `Compute-FrCount.ps1` partition logic; halt and surface |
| All 3 lanes complete but Phase 3.5 reports orphan FRs | `Verify-Coverage.ps1` exit 2 | Single-lane orphan-recovery dispatch (do not re-fan-out) |

---

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| Spawn 3 lanes serially (one Task block per orchestrator message) | Loses the parallelism that justifies fan-out — wall-clock equals 3 × single-lane | Single message, 3 Task blocks |
| Use `run_in_background: true` on Task tool | Confirmed bug per non-negotiable rules: hangs + empty outputs | Synchronous parallel Task calls |
| Skip `Compute-FrCount.ps1` and partition manually | Manual partition drifts; round-robin discipline lost | Always invoke the script and use its JSON output verbatim |
| Cap each lane to "first 5 FRs from partition" | Top-N capping antipattern per `rules/no-top-n-capping.md` | Each lane processes ENTIRE assigned partition |
| Have lanes share a single output file | File-write race | Each lane writes its own plan files; orchestrator concatenates |
| Skip Phase 3.5 coverage verification after fan-out | Orphan FRs go undetected (the iter 1-41 collab-engine failure mode) | Always run `Verify-Coverage.ps1` post-merge |
| Strip deferral keywords from FRs that genuinely have sanctioned deferrals | Violates `rules/no-silent-deferrals.md` asymmetry rule | Preserve verbatim; sentinel comment in scaffold protects from hook |

---

## Related

- `.claude/skills/testplan/SKILL.md` Phase 1 Step 1.0a — the gate that triggers this rubric.
- `.claude/scripts/Compute-FrCount.ps1` — partition computation.
- `.claude/scripts/Init-TestPlanScaffold.ps1` — scaffold per plan.
- `.claude/scripts/Stage-SubagentBundle.ps1` — Phase 0.6 bundle (read-once context).
- `.claude/scripts/Verify-Coverage.ps1` — Phase 3.5 coverage gate.
- `.claude/scripts/Get-SubagentPromptBoilerplate.ps1` — standard subagent prompt composer.
- `.claude/rules/agent-teams.md` — ≥3 parallel groups MANDATORY discipline this lane structure satisfies.
- `.claude/rules/no-top-n-capping.md` — exhaustive-enumeration discipline applied to each lane's partition.
- `.claude/rules/no-silent-deferrals.md` — deferral-inheritance sentinel rationale.
