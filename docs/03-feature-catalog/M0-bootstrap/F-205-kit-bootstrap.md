---
artifact-class: feature-ledger
generated-by: hand-authored (silent-deferral surfacing 2026-05-07)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: silent-deferral surfacing audit (.mad/reports/mad-council-claw-audit-2026-05-07.md in MAD - Clean kit)
    note: "Initial creation surfacing a silent-deferral. The mechanical 'copy MAD kit primitives into mad-council-claw' step was assumed by the foundational plan ('engine inherits, doesn't fork' — mad-kit-inventory.md:881; ~280 keep-tagged primitives) but was NEVER captured as an F-NNN, NEVER scheduled in any wave, AND not in dropped-with-rationale.md. Per .claude/rules/no-silent-deferrals.md the assumption-without-an-F-NNN IS the silent-deferral pattern. Surfacing here as F-205 (first available beyond F-127..F-204 wave-1 consolidation range) at the user's instruction. Authored against a CRITICAL set + 3 m-main-derived skill lifts (skill-sanitize, mcp-permission-validate, copilot-cli-bridge); full kit-copy is explicitly out-of-scope of v1 and tracked as a follow-on."
  - status: red (BATCH-4-BRIEF-LANDED)
    at: 2026-05-07
    by: orchestrator session 967a44fb (Batch 4C of 4)
    note: "Batch 4C of 4 in user-scoped sequence. Implementation directive added: Bootstrap-CouncilClawKit.ps1 authored by Batch 4B in MAD - Clean kit; 3 m-main-derived skills authored by Batch 4A in MAD - Clean kit. Concurrent main orchestrator (session 64bf21c6 or successor) can pick up F-205 next iter and run the script. Status remains RED until kit lands AND tests/node/F-205-kit-bootstrap.test.ts passes per red-green-rule. F-205 unblocks F-206..F-210 (m-relay lift ledgers, soft-blocked) AND enables the M19 reopen council-review verdict per docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md (which gates on /council-review skill availability post-Batch-4)."
feature-id: F-205
short-slug: kit-bootstrap
milestone: M0
provenance:
  surfaces:
    - kit:.claude/rules/
    - kit:.claude/hooks/
    - kit:.claude/skills/
    - kit:.claude/agents/
    - kit:.claude/scripts/
    - kit:.mad/templates/
    - kit:.mad/scripts/
    - kit:.mad/docs/
    - kit:CLAUDE.md
    - cp:m-main (Copilot CLI / m365 patterns informing the 3 lifted skills)
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-205-kit-bootstrap.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
red-green-rule: |
  RED   if ANY of the 8 acceptance items (a)-(h) below fails OR test file is missing OR runner returns non-zero exit.
  GREEN if ALL 8 acceptance items pass AND tests/node/F-205-kit-bootstrap.test.ts exists AND runner returns zero exit.
  LOCKED if GREEN AND docs/05-design-reviews/council-reviews/F-205-kit-bootstrap-review.md exists with verdict: ACCEPT (median confidence ≥ 80).
depends-on: [F-003]
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md, every adjacent surface NOT covered by this ledger is
  enumerated below with explicit rationale. None of these are silently dropped — each requires
  user discussion before promotion, and each will be tracked via its own F-NNN when promoted:

  1. **Full kit copy beyond CRITICAL set is deferred** to a follow-on F-NNN (TBD; currently
     unallocated). This ledger covers only the CRITICAL set (load-bearing rules + hooks +
     core skills + scripts + .mad/templates + .mad/scripts + .mad/docs + CLAUDE.md). The
     remaining ~50% of kit primitives (advisory rules, helper scripts, technology-specific
     pattern files for .NET/Cosmos/Bicep, etc.) are deferred. Re-open trigger: when an
     M2..M19 feature surfaces a need for a kit primitive not in the CRITICAL set, that
     feature's ledger lifts the primitive on demand.
  2. **LENS-CMS / LENS-DCS / LENS-LRMS-specific content is explicitly excluded.** This includes:
     - All `.claude/rules/patterns/_dotnet/` files (.NET-specific)
     - LENS-* deployment scripts (Ado-Build.ps1, Ev2-Deploy.ps1, Diagnose-LensDcsDeploy.ps1, Run-AciE2E.ps1, etc.)
     - LENS-* skills (lens-aspnet-structure, lens-pipeline-audit, lens-telemetry, lens-standards-audit, lens-engineering-craftsmanship, lens-multi-model-review)
     - LENS-* lessons files (lens-dcs-loop-lessons.md)
     - .mad/scratch/aci-* + dcs-* + cms-* state files
     - .mad/work-items/lens-dcs-standardization/ (work-item-specific state)
     This material is correctly LENS-only per .mad/reports/mad-council-claw-audit-2026-05-07.md
     and mad-kit-inventory.md disposition (~50 LENS-specific drops).
  3. **m-main-derived skills beyond the 3 named (skill-sanitize, mcp-permission-validate,
     copilot-cli-bridge) are deferred.** m-main contains additional skill-shaped patterns
     (e.g. broader Copilot CLI orchestration, m365 auth helpers, voice-toolkit) that may be
     useful but require explicit user discussion before lifting. No silent additions.
  4. **Path rewriting (LENS_REPOS_ROOT analog → CLAW_REPOS_ROOT or equivalent) is partial-scope:**
     settings.local.json env path-rewriting is in scope; full audit-and-rewrite of every
     hardcoded path across .claude/scripts/*.ps1 is deferred to a follow-on lane. Acceptance
     item (e) covers settings.local.json only; the script-side audit is out-of-scope here.
  5. **Engine-runtime artifacts (run.json, retro.json, audit-log.jsonl, cost-ledger.jsonl,
     soul.json, kill-switches/, .collab-engine/)** belong to F-001 + F-008 + F-014..F-022,
     NOT to this ledger. F-205 covers the substrate (rules, hooks, skills, scripts) only.
  6. **Schema directory creation (.mad/schemas/) — referenced by mad-kit-inventory.md
     line 885 as needing explicit creation — is deferred** to whichever feature first
     consumes a canonical artifact frontmatter check. F-205 does NOT create .mad/schemas/.
confidence: high
---

# F-205 — Kit bootstrap

## Rationale

The mad-council-claw foundational plan assumes "engine inherits, doesn't fork" the MAD kit:

- `docs/04-research/mad-kit-inventory.md:881`: "Most kit primitives transfer cleanly — the kit was developed AS the substrate for the engine; ~80% of primitives are domain-neutral."
- `docs/04-research/mad-kit-inventory.md:872-877`: disposition summary tags ~280 primitives `keep`, ~10 `change`, ~50 `drop` (LENS-specific), ~35 `defer`, ~3 `decision-pending`.
- `docs/06-agent-team-outputs/wave-001/lane-d-summary.md:99`: "Most kit primitives transfer cleanly (~80% domain-neutral). Engine inherits, doesn't fork."
- `docs/04-research/openclaw-clawpilot/lessons-learned.md:172`: "take Clawpilot's IPC + backend + permission + skills + MCP + auth shapes, layer in MAD.Council's owner-accountability + canonical artifact + concurrency-safety rules."

But the **mechanical step** of copying the keep-tagged primitives into mad-council-claw was never captured as an F-NNN. Reviewing every artifact:

- `docs/10-backlog/implementation-todo.md` lists F-001..F-008, F-127, F-167, F-171 for M0; **no kit-bootstrap entry**.
- `docs/03-feature-catalog/M0-bootstrap/README.md` enumerates F-001..F-008; **no kit-bootstrap entry**.
- `docs/10-backlog/dropped-with-rationale.md`: empty (no entries) — so this is not a documented drop.
- `roadmap.md` M0 milestone overview row (line 32): F-001..F-008, total 8; **no kit-bootstrap counted**.

Per `.claude/rules/no-silent-deferrals.md`: "Don't quietly drop features the user asked for. If something the user wants doesn't fit current scope, raise it as a discussion." The mad-kit-inventory.md disposition is effectively a user-stated intent ("keep these ~280 primitives"); the absence of an F-NNN to do the actual work is the silent-deferral pattern. This ledger surfaces that.

The audit at `.mad/reports/mad-council-claw-audit-2026-05-07.md` (in the MAD - Clean kit; agentId a840240f759f96cdc) flagged this as a CRITICAL gap at user instruction. The user has confirmed scope: CRITICAL set + 3 m-main-derived skill lifts.

## Behavior contract

The mad-council-claw repo carries enough MAD kit substrate at v1 to (a) enforce the same antipattern hooks the engine runtime depends on (`content-scan-deferrals.js`, `validate-mad-pipeline.js`, `enforce-skill-canonical-marker.js`, `detect-top-n-capping.js`, `enforce-orchestration.js`), (b) author canonical MAD artifacts via the `/mad-*` skill chain, (c) run `/council-*` skills for governance reviews, (d) dispatch parallel sub-agents per agent-teams.md, and (e) orchestrate Copilot CLI cross-model dispatch via the m-main-derived `copilot-cli-bridge` skill.

"Kit-bootstrap complete" means the 8 items below pass concurrently against a fresh checkout.

## Acceptance scenarios (8 items, exhaustively enumerated)

1. **(a) `.claude/` populated with CRITICAL set.** `.claude/rules/`, `.claude/hooks/`, `.claude/skills/`, `.claude/agents/`, `.claude/scripts/`, `.claude/settings.json`, `.claude/settings.local.json` all exist with the keep-tagged primitives. Specifically:
   - `.claude/rules/` MUST include all load-bearing antipattern rules (no-silent-deferrals.md, no-top-n-capping.md, canonical-skill-only.md, canonical-artifact-frontmatter.md, scope-discipline.md, autonomous-loop-discipline.md, loop-cadence-discipline.md, loop-stop-language-discipline.md, no-invented-constraints.md, orchestration.md, orchestrator-identity.md, verification-protocol.md, minimum-change.md, agent-teams.md, anomaly-thresholds.md, context-guardian.md, non-negotiable-rules.md, prompt-injection-policy.md, dangerous-operations-policy.md, degradation-fallback-policy.md, stride-threat-model.md, single-owner-accountability.md, triage-gate.md, concurrency-safety.md, skill-standards.md, mad-workflow.md, quality-gates.md, review-gate-protocol.md, council-verdict-artifact.md, prescriptive-content-review.md, lens-multi-model-review-pattern.md, _status-convention.md).
   - `.claude/hooks/` MUST include the 5 load-bearing antipattern hooks (per `mad-kit-inventory.md:883`): `content-scan-deferrals.js`, `validate-mad-pipeline.js`, `enforce-skill-canonical-marker.js`, `detect-top-n-capping.js`, `enforce-orchestration.js`. Also: `track-mad-skill-invocation.js`, `validate-artifact-completeness.js`, `record-skill-completion.js`, `pre-bash-validate.js`, `pre-commit-validate.js`, `validate-quality-gates.js`.
   - `.claude/skills/` MUST include the 5 canonical MAD skills (`mad-spec`, `mad-plan`, `mad-tasks`, `mad-analyze`, `testplan` AKA `mad-testplan`) + `mad-implement` + `mad-validate` + the 5 council skills (`council-open`, `council-join`, `council-leave`, `council-list`, `council-check`, `council-post`, `council-review`, `council-resolve`, `council-retro`, `council-verdict`) + `loop` + `apply-learnings`.
   - `.claude/agents/` MUST include `code-investigator`, `code-implementer`, `code-reviewer`, `domain-reviewer`, `research-scout`, `research-curator`, `research-reviewer`, `parallel-researcher`, `janitor`, `work-planner`, plus the 3 composite agents (`investigate-and-implement`, `review-and-fix`, `coverage-loop`).
   - `.claude/scripts/` MUST include the kit-generic scripts (Check-Preflight.ps1, Verify-Health.ps1, Check-LoopStopConditions.ps1, Track-SkillMetrics.ps1, Invoke-CopilotMultiModel.ps1, Verify-CanonicalSkillFrontmatter.ps1, Validate-CouncilVerdict.ps1, Detect-ContentType.ps1, Detect-ScopeClaimDrift.ps1, Pull-ProductionGrounding.ps1, regex-spotcheck.js). LENS-specific scripts excluded per out-of-scope-notes.

2. **(b) `.mad/` populated with non-LENS portions.** `.mad/templates/` (canonical artifact templates: idea.md, spec.md, plan.md, tasks.md, analysis-report.md, test-plan.md, coverage-oracles/), `.mad/scripts/` (Run-DotnetGates.ps1 omitted; kit-generic scripts only), `.mad/docs/` (workflow-best-practices, progressive-validation-guide, context-management-guide, reference-repos.md, best-practices/README, etc.). `.mad/scratch/` directory created with `.gitkeep`. `.mad/reports/` directory created with `.gitkeep`. `.mad/work-items/` directory created with `.gitkeep`. LENS-CMS/DCS/LRMS-specific content explicitly excluded per out-of-scope-notes.

3. **(c) `CLAUDE.md` authored at root scoped to council-claw.** The root `CLAUDE.md` is council-claw-specific (not LENS-DCS-shaped); it explains the 6-phase substrate model (engine inherits MAD kit), references the foundational-plan.md, names the canonical skill chain, and cites the load-bearing antipattern rules. It does NOT inherit the LENS-DCS standardization-loop CLAUDE.md verbatim. Per `.claude/rules/canonical-skill-only.md` and `verification-protocol.md`.

4. **(d) 3 new skills authored from m-main patterns:**
   - **`skill-sanitize`** — input-sanitization skill that strips smart-unicode, prompt-injection patterns, and over-broad role-reassign directives from any user-supplied content before it reaches a code-implementer or council-reviewer. Lifted from m-main's input-handling layer; adapted to council-claw's `/council-post` + `/council-review` entry surfaces.
   - **`mcp-permission-validate`** — pre-tool-call validator that checks an MCP tool invocation against a per-workspace permissions file (default-deny + explicit allowlist). Lifted from m-main's permission-tier surface; adapted to council-claw's M7 (Skills + Permissions + Automations) pre-flight.
   - **`copilot-cli-bridge`** — Task-tool subagent shape that dispatches a brief to Copilot CLI (parallel `copilot --yolo -p` to Opus + GPT-5+), reads `<OutputDir>/{opus,gpt}-result.json`, and returns the cross-model agreement table. Lifted from m-main's Copilot CLI integration; honors `.claude/rules/lens-multi-model-review-pattern.md` (renamed to `multi-model-review-pattern.md` post-LENS-strip) and `orchestrator-identity.md` Rule 1 (orchestrator never invokes the dispatcher script directly; always routes through a Task subagent).

5. **(e) settings.local.json env path-rewritten.** The `LENS_REPOS_ROOT` env var (or analog, e.g. `MAD_REPOS_ROOT`) is rewritten to point at the council-claw checkout root (or equivalent council-claw-scoped path). `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set per `.claude/rules/agent-teams.md`. Other LENS-specific env vars (PUSH_GUARD_MODE, MCP_TIER_ENFORCE, etc.) are reviewed and either kept (kit-generic) or stripped (LENS-specific). Full hardcoded-path audit across `.claude/scripts/*.ps1` is deferred per out-of-scope-notes #4.

6. **(f) Hooks fire end-to-end on a synthetic test.** A test file (e.g. `tests/node/F-205-kit-bootstrap.test.ts`) writes a synthetic deferral keyword (`"deferred to v1.5"`) to `.mad/scratch/test-deferral-fixture.md`; the `content-scan-deferrals.js` PostToolUse hook fires and appends a violation to `.mad/scratch/deferral-flags.json`. Also: a synthetic Top-N cap phrase (`"top 5 findings"`) in a Task-tool prompt is BLOCKED by `detect-top-n-capping.js` PreToolUse hook unless the exhaustive-enumeration sentinel is present. Hook exemption paths (e.g. `.mad/reports/`, `.mad/scratch/*-flags.json`, `dropped-with-rationale.md`) are honored.

7. **(g) `/council-list` returns "no channels" without error.** Per `.claude/skills/council-list/SKILL.md`, invoking `/council-list` against a fresh council-claw checkout (which has no channels yet) succeeds with exit 0 and reports the empty-channel state explicitly (per `.claude/rules/skill-standards.md` Dimension 2 anti-hallucination: empty categories must be stated explicitly, not silently dropped). Validates that the council-* skill chain is wired and the channel-state directory layout (`.mad/channels/` or equivalent per `concurrency-safety.md`) is initialized.

8. **(h) `/mad-spec` dry-run produces a frontmatter-valid stub.** Invoking `/mad-spec --dry-run` (or equivalent stub-mode) against a synthetic feature description produces a `specs/<N>-<feature>/spec.md` file whose frontmatter satisfies `.claude/rules/canonical-artifact-frontmatter.md` (`generated-by: /mad-spec` + `generated-by-version: <semver>` + `skill-state-file-id: <session-id>`) AND passes `.claude/scripts/Verify-CanonicalSkillFrontmatter.ps1` validation. Validates that the canonical-skill chain is functional end-to-end.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/node/F-205-kit-bootstrap.test.ts` | node | RED — directory existence assertions fail (`.claude/rules/`, `.claude/hooks/`, etc. not yet populated); skill-presence assertions fail; hook-fires-on-synthetic-fixture assertion fails | acceptance items (a)-(h); structural via `existsSync` + `readFileSync` + child-process invocation of hook scripts on synthetic input |
| (deferred to F-205-LOCKED follow-on) `tests/integration/kit-bootstrap/copilot-cli-bridge-roundtrip.test.ts` | integration | RED — requires Copilot CLI installed; fallback path verifies same-model role-split per `.claude/rules/lens-multi-model-review-pattern.md` Fallback section | item (d) `copilot-cli-bridge` skill end-to-end (excluded from initial GREEN per `degradation-fallback-policy.md` Rule 1: optional dependency) |

## Dependencies

- **Hard:** F-003 (repo-scaffolding — packages/scripts/.mad must exist before kit primitives can land)
- **Soft:** F-007 (IPC contract scaffold — copilot-cli-bridge eventually delivers results to the renderer via IPC), F-127 (three-tier-eval-harness — kit-bootstrap installs the eval substrate; F-127 consumes it to scaffold per-feature RED tests)
- **Independent:** F-001 (engine kernel; runs after F-205 substrate exists), F-009 (IBackendProvider; M1 milestone independent)

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:.claude/rules/ | The ~30 load-bearing antipattern rules (no-silent-deferrals, no-top-n-capping, canonical-skill-only, etc.) the engine runtime enforces |
| kit:.claude/hooks/ | The 5+ PreToolUse / PostToolUse / SubagentStop hooks that mechanically enforce the rules |
| kit:.claude/skills/ | 5 canonical MAD skills + 10 council-* skills + composite agents |
| kit:.claude/agents/ | code-investigator, code-implementer, code-reviewer, domain-reviewer, research-scout/curator/reviewer, janitor, work-planner |
| kit:.claude/scripts/ | Generic preflight, gate, frontmatter-validator, copilot-multi-model dispatcher, content-type detector |
| kit:.mad/templates/ | Canonical artifact templates (idea, spec, plan, tasks, analysis-report, test-plan) + coverage-oracles/ per `prescriptive-content-review.md` Gap 3 |
| kit:.mad/scripts/ | Kit-generic helper scripts (Run-DotnetGates.ps1 excluded; LENS-only) |
| kit:.mad/docs/ | Workflow-best-practices, progressive-validation-guide, context-management-guide, reference-repos.md |
| kit:CLAUDE.md | Council-claw-scoped root brief explaining substrate model + canonical skill chain + load-bearing rules |
| cp:m-main | Source patterns for the 3 lifted skills (skill-sanitize, mcp-permission-validate, copilot-cli-bridge) |

## Implementation notes

This ledger is RED on creation. Implementation lands in a follow-on wave (likely wave-15+) per the multi-instance pickup protocol in `docs/11-loop-state/README.md`. The implementation MUST be split into 4 batches per the user's verify-each request:

- **Batch 1** (this batch): F-205 ledger + roadmap + implementation-todo.md row authored. NO kit files copied. NO mad-council-claw runtime files modified.
- **Batch 2** (future): CRITICAL set rule-and-hook copy from MAD - Clean → mad-council-claw, with LENS-strip per `out-of-scope-notes` #2.
- **Batch 3** (future): 3 m-main-derived skills authored (skill-sanitize, mcp-permission-validate, copilot-cli-bridge).
- **Batch 4** (future): settings.local.json env path-rewriting + CLAUDE.md root authoring + RED test (`tests/node/F-205-kit-bootstrap.test.ts`) + RED-state captured. GREEN flip is a separate subsequent wave gated on `/council-review` ACCEPT.

Per `.claude/rules/minimum-change.md`: this ledger captures the contract and out-of-scope, nothing more. The kit copy itself is a separate scope.

## Implementation directive

This section is added by Batch 4C (orchestrator session `967a44fb`, 2026-05-07) to point the concurrent main orchestrator (session `64bf21c6` or successor) at the deliverables produced by sibling Batch 4A + 4B. F-205 implementation is now unblocked — the missing pieces from the original "Implementation notes" Batch 2 + Batch 3 + Batch 4 prose are landed in the MAD - Clean kit and ready to be invoked.

### Bootstrap script location

```
Script: C:/Users/tonym/Repos/MAD - Clean/.claude/scripts/Bootstrap-CouncilClawKit.ps1
```

Authored by Batch 4B implementer 2026-05-07 in the MAD - Clean kit. Assumed to exist and be invocable; verification of the script itself is Batch 4D's dry-run job (out of scope for this ledger update per `.claude/rules/minimum-change.md`).

### Invocation example

```powershell
pwsh -NoProfile -File "C:/Users/tonym/Repos/MAD - Clean/.claude/scripts/Bootstrap-CouncilClawKit.ps1" `
  -TargetRepo "C:/Users/tonym/Repos/mad-council-claw" `
  -Tier critical `
  -DryRun
# Review the dry-run output. Then execute without -DryRun.
```

### Three m-main-derived skills now in kit

Authored by Batch 4A implementer 2026-05-07 in the MAD - Clean kit. The bootstrap script copies these alongside other CRITICAL kit content into mad-council-claw at execution time:

- `MAD - Clean/.claude/skills/skill-sanitize/SKILL.md` — input sanitization (smart-unicode strip, prompt-injection pattern strip, role-reassign directive strip) per acceptance item (d) bullet 1.
- `MAD - Clean/.claude/skills/mcp-permission-validate/SKILL.md` — pre-tool-call MCP permission validator (default-deny + explicit allowlist) per acceptance item (d) bullet 2.
- `MAD - Clean/.claude/skills/copilot-cli-bridge/SKILL.md` — Task-tool subagent shape that dispatches to Copilot CLI (parallel `copilot --yolo -p` Opus + GPT-5+) and returns the cross-model agreement table; honors `orchestrator-identity.md` Rule 1 per acceptance item (d) bullet 3.

### Pre-execution checklist for the executing session

The concurrent main orchestrator MUST verify each of the following before invoking the bootstrap script:

- [ ] Concurrent session HAS halted any in-flight wave work (no uncommitted drift in `.claude/`, `.mad/`, root `CLAUDE.md`)
- [ ] git working tree status reviewed; safe to add ~50 new files + adapted `CLAUDE.md`
- [ ] `pwsh -Version` ≥7 available
- [ ] DryRun output reviewed and approved
- [ ] User notified that Batch 4 execution is happening

### Post-execution acceptance check (mapping back to F-205 (a)-(h))

The script's output report should answer Y/N for each of the 8 acceptance items enumerated in `## Acceptance scenarios` above. If Y for ALL 8 → the executing session flips status RED → GREEN (after authoring `tests/node/F-205-kit-bootstrap.test.ts` per the F-205 `red-green-rule` to mechanically verify the kit landed cleanly). Per `.claude/rules/no-top-n-capping.md`, every item is enumerated explicitly:

- (a) `.claude/` populated with CRITICAL set — Y/N (script reports rules / hooks / skills / agents / scripts presence counts).
- (b) `.mad/` populated with non-LENS portions — Y/N (script reports templates / scripts / docs presence; `.mad/scratch/`, `.mad/reports/`, `.mad/work-items/` directories created with `.gitkeep`).
- (c) `CLAUDE.md` authored at root scoped to council-claw — Y/N (script reports council-claw-specific CLAUDE.md exists and is NOT a verbatim LENS-DCS copy).
- (d) 3 new skills authored from m-main patterns — Y/N (script reports `skill-sanitize/SKILL.md`, `mcp-permission-validate/SKILL.md`, `copilot-cli-bridge/SKILL.md` all present in target).
- (e) `settings.local.json` env path-rewritten — Y/N (script reports `LENS_REPOS_ROOT` analog rewritten to council-claw scope; `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` set; LENS-specific env vars triaged).
- (f) Hooks fire end-to-end on a synthetic test — Y/N (test file exercises `content-scan-deferrals.js` PostToolUse + `detect-top-n-capping.js` PreToolUse against synthetic fixtures).
- (g) `/council-list` returns "no channels" without error — Y/N (script invokes the skill against fresh checkout; exit 0; explicit empty-state report per `skill-standards.md` Dimension 2 anti-hallucination).
- (h) `/mad-spec` dry-run produces a frontmatter-valid stub — Y/N (script invokes `/mad-spec --dry-run`; resulting `specs/<N>-<feature>/spec.md` passes `Verify-CanonicalSkillFrontmatter.ps1`).

### Status transition note

- F-205 stays RED until the script executes AND `tests/node/F-205-kit-bootstrap.test.ts` exists AND that test passes.
- Then RED → GREEN per `status-history` (the executing session appends a new YAML entry citing wave/lane + green-evidence + test-output path).
- Then GREEN → LOCKED per a separate `/council-review` verdict at HIGH ≥80% (artifact at `docs/05-design-reviews/council-reviews/F-205-kit-bootstrap-review.md` per the `red-green-rule` LOCKED clause).

### Cross-feature unblock note

F-205 GREEN unblocks F-206..F-210 (m-relay lift ledgers, currently soft-blocked on the kit substrate landing) AND enables the M19 reopen council-review verdict per `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md` (which gates on `/council-review` skill availability post-Batch-4).

## References

- `.mad/reports/mad-council-claw-audit-2026-05-07.md` (in `C:\Users\tonym\Repos\MAD - Clean`) — the audit that surfaced this gap (agentId `a840240f759f96cdc`).
- `docs/04-research/mad-kit-inventory.md:881` — "Most kit primitives transfer cleanly — the kit was developed AS the substrate for the engine."
- `docs/04-research/mad-kit-inventory.md:872-877` — disposition summary (~280 keep, ~10 change, ~50 drop, ~35 defer, ~3 decision-pending).
- `docs/06-agent-team-outputs/wave-001/lane-d-summary.md:99` — "Engine inherits, doesn't fork."
- `docs/04-research/openclaw-clawpilot/lessons-learned.md:172` — synthesis of clawpilot + canonical-e + MAD.Council kit shapes.
- `docs/10-backlog/dropped-with-rationale.md` — empty (proves this was not a documented drop, hence silent-deferral pattern).
- `docs/10-backlog/implementation-todo.md:13-27` — M0 backlog table; demonstrates F-205 absence pre-this-commit.
- `.claude/rules/no-silent-deferrals.md` (in MAD - Clean kit) — the rule that mandates surfacing this.
- `docs/03-feature-catalog/M0-bootstrap/F-001-engine-bootstrap-loop.md` — canonical-shape ledger sample (LOCKED).
- `docs/03-feature-catalog/M0-bootstrap/F-007-ipc-contract-scaffold.md` — RED-then-LOCKED ledger sample.
- `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md:60-68` — F-127..F-204 allocation range; F-205 is first beyond reserved padding.
