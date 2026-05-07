---
title: Cross-source disposition matrix — kit + canonical-e + clawpilot
sources:
  - C:\Users\tonym\Repos\MAD - Clean\.claude\ + .mad\
  - C:\Users\tonym\Repos\MAD - Clean\specs\15-collab-engine-canonical-e\
  - C:\Users\tonym\Repos\mad-council-claw\docs\04-research\openclaw-clawpilot\ (Lane C; not yet committed)
date: 2026-05-06
wave: wave-001
lane: lane-d
topic: cross-source-disposition-matrix
confidence: MEDIUM
---

# Cross-source disposition matrix

3-source synthesis: every surface from each source mapped to keep/change/drop/new for the new collab engine.

**Sources**:
- **K** = MAD kit primitives (`.claude/` + `.mad/`)
- **CE** = canonical-e spec (`specs/15-collab-engine-canonical-e/`)
- **CP** = openclaw-clawpilot inventory (Lane C output; **NOT YET COMMITTED** as of 2026-05-06)

## Lane C status note

Lane C (openclaw-clawpilot) commits had not landed when Lane D ran. The openclaw-clawpilot reference repo exists at `references/openclaw-clawpilot` (per `docs/04-research/openclaw-clawpilot/` directory placeholder) but the inventory file `clawpilot-features-inventory.md` was empty at Lane D scan time.

**This matrix is therefore 2-source verified (K + CE) with CP rows marked `[NEEDS LANE C]`**. Wave-2 cross-walk will fold in the CP source once Lane C commits.

## Engine surface taxonomy

The engine's surface area decomposes into ~12 canonical surfaces. Each gets a row showing source-coverage + disposition.

| Engine surface | K coverage | CE coverage | CP coverage | Engine disposition |
|---|---|---|---|---|
| **MAD pipeline (skill chain)** | 8 skills + 4 orchestrators | All 7 phases align; FR-CORE-001..005 references | [NEEDS LANE C] | keep K (engine consumes) |
| **Council primitives** | 10 council-* skills + 3 council rules | FR-OVERRIDE-001 + FR-CORE-005 + verdict mechanics | [NEEDS LANE C] | keep K (verbatim contract) |
| **Loop substrate** | `/loop` skill + loop-cadence + autonomous-loop rules | FR-CORE-001..005 + FR-PROACTIVE-001 + cron mechanics | [NEEDS LANE C] | keep K + CE detail |
| **Soul + boundaries** | (none in K) | FR-SOUL-001 + FR-SOUL-SCHEMA-001 + SoulDocument entity | [NEEDS LANE C — likely CP source] | new (build per CE) |
| **Supervisor + peer-agents** | (orchestration.md + agent-teams.md cover the discipline) | FR-SUPERVISOR-001 + FR-IDENTITY-001 (v1 chain) + Peer-Agent entity | [NEEDS LANE C] | new entities (build per CE) + keep K rules |
| **Audit + privacy** | (none in K) | FR-AUDIT-001/002 + FR-AUDIT-PRIVACY-001 + AuditEvent entity | [NEEDS LANE C] | new (build per CE; hash chain + JSONL) |
| **Cost ledger** | (none in K; only token-budget hooks) | FR-COST-001/002/003 + CostLedgerEntry entity | [NEEDS LANE C] | new (build per CE; observability-only) |
| **Skills allowlist + governance** | skill-standards.md + canonical-skill-only.md | FR-GOV-001..004 + SkillAllowlistEntry entity | [NEEDS LANE C] | new (build per CE; sha256 pinning) |
| **Halt + override + kill-switch** | (no K equivalent) | FR-KILL-001 + FR-OVERRIDE-001 + FR-DEGRADE-001 + KillSwitch entity | [NEEDS LANE C] | new (build per CE; precedence ladder load-bearing) |
| **Multi-model dispatch** | `Invoke-CopilotMultiModel.ps1` + `lens-multi-model-review-pattern.md` | FR-MULTI-001/002 (in-trust-boundary v1) | [NEEDS LANE C] | keep K dispatcher + CE rule |
| **M365 surfaces (adapters)** | `workiq-scan` skill (existing); no Outlook/Teams adapter | FR-WORKIQ-001/002, FR-OUTLOOK-001, FR-TEAMS-001/002, FR-AGENT365-001 | [NEEDS LANE C — likely CP-heavy] | new (build per CE; Phase 4) |
| **Replay** | (no K) | FR-REPLAY-001 + ReplayManifest entity | [NEEDS LANE C] | new (build per CE; narrow scope) |
| **Heartbeat / cron** | scheduled-trigger-heartbeat.md pattern | FR-PROACTIVE-001 + CronFireRecord entity | [NEEDS LANE C] | keep K pattern + new entity per CE |
| **Hooks (PreToolUse + PostToolUse + ...)** | 49 hooks | (CE consumes via canonical-skill-only enforcement) | [NEEDS LANE C] | keep K (load-bearing) |
| **Templates + coverage oracles** | 41 templates + 12 oracles | (CE produced via these) | [NEEDS LANE C] | keep K + add 8 engine-runtime template categories |
| **Schemas** | (empty `.mad/schemas/`; live inline) | All 19 entities need JSON Schemas | [NEEDS LANE C] | new directory (`schemas/` at engine root or `.mad/schemas/`) |

## Disposition matrix — combined

### Surfaces present in K only

| Surface | Disposition for engine | Rationale |
|---|---|---|
| 49 hooks | keep | Already load-bearing; 5 anti-pattern hooks non-negotiable |
| 41 templates + 12 oracles | keep | Engine v1 doesn't need to redesign these |
| 80 wiki docs | keep (most) + drop (LENS-specific 5) | Same as kit-inventory.md |
| 175 scripts (101 + 74) | keep (~125) + drop (~50 LENS-specific) | Same as kit-inventory.md |
| MAD pipeline orchestration skills (mad-full / mad-decompose / mad-parallel) | keep | Engine consumes |
| 70 skills | keep (~62) + drop (~5 LENS) + change (~3) | Same as kit-inventory.md |
| 96 rules + patterns | keep (~85) + drop (~5 LENS) + change (~5) + defer (~32 .NET) | Same as kit-inventory.md |

### Surfaces present in CE only

| Surface | Disposition for engine | Rationale |
|---|---|---|
| 49 distinct FRs | keep 38 + defer 11 | All 11 defers are sanctioned (Cat-B traceable) |
| 8 USs (P1×3 + P2×4 + P3×1) | keep all | P1 = engine v1 must-have |
| 17 SCs | keep all | SC-001 + SC-002 + SC-005 = ship gates |
| 19 entities | keep 18 + defer 1 (TenantRollupRow) | Schema work needed for all |
| 12 event types | keep 11 + defer 1 (Tenant Rollup) | Stable schemas in events.md |
| 72 error codes | keep 70 + defer 1 + drop 2 | Comprehensive error taxonomy |
| 7 phases (Phase 0..6) | keep all | Engine implementation roadmap |
| 88 test cases | keep all | Test plan ready |
| 24 OoS items | respect verbatim | Enforced via FR-MUST-NOT-001 grep gate |
| 11 v1.5 sanctioned deferrals | defer | All have v1 substitute documented |
| 6 FR-ASSUME-* assumptions | keep doc-only | Trust boundary acknowledgements |

### Surfaces present in CP only (predicted; awaiting Lane C)

Per the openclaw-clawpilot reference repo's likely surface area:
- TBD — needs Lane C inventory
- Probable CP-unique: Lobster pillars (Device & App Runtime, Personal Assistant, Collaboration Engine, Memory & Identity, Marketplace), Teams-integration patterns, M365-bot skeleton, Electron-host scaffolding (drop per CE OoS#9).
- Predicted overlap with CE: Soul boundaries, Supervisor pattern (CE marks both as new entities; CP likely had earlier formulation).

[NEEDS LANE C TO CONFIRM/REFUTE]

### Surfaces predicted to be `new` (no K + no CE source)

| Surface | Rationale | Likely source |
|---|---|---|
| Engine runtime persistence directory layout (`~/.collab-engine/`) | CE references it but doesn't define filesystem hierarchy | Engine bootstrap design |
| OAuth grant cache (`<channel-dir>/oauth-grants/<adapter>.json`) | CE FR-EXT-WRITE-SCOPE-001 references; no K equivalent | Build per CE Phase 4 |
| Skill allowlist file location (`.mad/policy/skills-allowlist.json`) | CE references; K has no allowlist file | Build per CE Phase 2 |
| Soul document file location (`.mad/policy/soul.json`) | CE references; K has no soul file | Build per CE Phase 0 |
| Kill-switch directory (`.mad/policy/kill-switches/<change-id>.json`) | CE references; K has no kill-switch | Build per CE Phase 2 |
| Calibration approvals touch-file directory | CE references; K has no equivalent | Build per CE Phase 3 |
| Replay manifests directory (`replay-manifests/<run_id>.json`) | CE references; K has no equivalent | Build per CE Phase 4 |
| External-write rate-cap policy file (`.mad/policy/external-write-rates.json`) | CE references; K has no equivalent | Build per CE Phase 2/4 |

## Cross-source conflict resolution

Where K and CE differ, Lane D applies these resolution rules:

| Conflict | Resolution | Rationale |
|---|---|---|
| K's `mad-teams` skill predates Council primitives (council-*) | drop mad-teams; CE Council primitives are authoritative | CE is the matured contract |
| K's `agent-teams.md` rule says "≥3 parallel groups MANDATORY"; CE FR-CORE-003 caps at 50 cycles | both apply orthogonally; no conflict | Different layers |
| K's loop-cadence-discipline.md zones (270s, 1500s); CE references `Schedule(d trigger)` heartbeat pattern | K cadence + CE pattern coexist | Cadence = orchestrator; heartbeat = cron-fire |
| K has no Soul concept; CE has FR-SOUL-001 | new (build per CE) | CE introduces this concept |
| K's `lens-multi-model-review-pattern.md` references `Invoke-CopilotMultiModel.ps1`; CE FR-MULTI-001 references same | rename: drop `lens-` prefix on rule | CE makes it generic |
| K's hooks have no Soul-violation detector; CE references engine "re-evaluates Soul invariants on every operation" | new hook needed: `enforce-soul-boundary.js` | Build new |
| K has `cleanup-scratch.ps1`; CE FR-ARCHIVE-001 deferred | keep K's cleanup; FR-ARCHIVE-001 is broader (auto-archive past size/age thresholds) | Different scopes |

## Engine surface — composite disposition

Combining all sources, the engine v1 surface decomposes into:

| Layer | Source contribution | Engine action |
|---|---|---|
| **Bootstrap (Phase 0)** | CE FR-IDENTITY-001 (chain) + CE FR-SOUL-SCHEMA-001 + CE FR-SUPERVISOR-001 + K mode 0700 ACL via FR-ISOLATION-001 | New code; new schemas; reuse K's `atomic-write.ps1` |
| **Engine Core (Phase 1)** | CE FR-CORE-001..005 + K `/loop` skill + K `Stage-SubagentBundle.ps1` | Reuse K loop substrate; build CE Run/Cycle state machine on top |
| **Governance + Halts (Phase 2)** | CE FR-GOV-001..004 + CE FR-KILL-001 + CE FR-OVERRIDE-001 + CE FR-DEGRADE-001 + K skill-standards.md | New skill allowlist + kill-switch + override mechanics |
| **Audit + Multi-Model (Phase 3)** | CE FR-AUDIT-001/002 + CE FR-AUDIT-PRIVACY-001 + CE FR-MULTI-001/002 + K `Invoke-CopilotMultiModel.ps1` | New audit log; reuse K dispatcher |
| **M365 + Replay (Phase 4)** | CE FR-WORKIQ + FR-OUTLOOK + FR-TEAMS + FR-AGENT365 + FR-REPLAY-001 + K `workiq-scan` skill (existing) | New M365 adapters; reuse K WorkIQ skill |
| **Identity + Symlink Defense (Phase 5)** | CE FR-INTROSPECT-002 + CE FR-ISOLATION-002 + CE FR-FAIRNESS-001 conditional | New Grader entity; new isolation hardening |
| **Acceptance + Hardening (Phase 6)** | CE SC verification + K `Run-DotnetGates.ps1` (defer; .NET only) + K `Verify-Health.ps1` | New eval scenarios per CE SCs |

## Open questions / decision-pending

| Question | Source | Action |
|---|---|---|
| Schema directory location: `.mad/schemas/` or `schemas/`? | K kit-inventory.md | Lane Zero confirms |
| `mad-teams` vs `council-*`: drop mad-teams or reconcile? | K | engine architecture decision |
| `lens-engineering-craftsmanship`: rename + generalize, or drop? | K | preserve generic voice toolkit; reframe |
| Re-import 7 missing predecessor skills (`ecosystem-improve`, `failure-analyze`, `registry-{install,list,sync}`, `session-review`, `mad-testplan`)? | CE OoS #12 | iter 5+ rename verification |
| Does Lane C add CP-unique surfaces not in CE? | CP | wave-2 cross-walk |
| Does the engine ship as a npm package, .NET tool, or PowerShell module? | (no source) | engine architecture decision |
| Does engine v1 ship with all 7 phases, or stage Phase 0-3 first then Phase 4-6 in v1.x? | CE | engine architecture decision |

## Commit-confidence note

This matrix is **MEDIUM confidence** until Lane C's CP inventory commits. Wave-2 cross-walk will:
1. Read `docs/04-research/openclaw-clawpilot/clawpilot-features-inventory.md` once Lane C lands
2. Annotate all `[NEEDS LANE C]` rows
3. Surface any CP-unique surfaces not predicted here
4. Resolve any K-vs-CP conflicts (likely small; CP should already align with CE since CE is the current matured spec)

The K + CE cross-walk (~85% of the matrix surface) is **HIGH confidence** as both sources were directly enumerated in this lane.
