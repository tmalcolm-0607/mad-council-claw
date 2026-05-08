# Implementation: Marketplace Plugins (playground-main)

**What it is:** A curated summary of the `playground-main` plugin marketplace — 630 plugins, 2651 skills, 869 agents — focusing on the ones MAD.Council directly borrows from. Grounded in the 10-iteration review documented at `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md` (138 HIGH-confidence patterns, 13 confirmed industry gaps).

**Role in MAD.Council:** Primary pattern source. Every rule and pattern in the MAD wiki traces to one or more marketplace plugins. This page catalogs the plugins worth reading directly.

**Last verified:** 2026-04-17.

## The 14 cross-cutting patterns (executive summary)

These are the dominant patterns found across the review. Each is documented in a dedicated wiki page; here's the attribution table so you know where to look when you want the source.

| Pattern | Canonical source plugin(s) | Wiki page |
|---|---|---|
| Orchestrator-only identity | `plugins/zen-agents/agents/orchestrator.md`, `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md` | `wiki/patterns/orchestrator-worker.md`, `rules/orchestrator-identity.md` |
| State files as coordination | `plugins/ai-native-team/` (plan.md), `plugins/a11y-remediation/` (a11y-session.yaml), MAD `.claude/work-items/` | `wiki/patterns/state-file-coordination.md` (future) |
| JSON structured contracts | `plugins/ai-native-team/agents/code-reviewer.md`, `plugins/review-verdict/` | `wiki/patterns/multi-role-review.md` |
| run_id / sessionId correlation | `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md`, `plugins/typescript-updater/` | `wiki/patterns/run-id-correlation.md` |
| Bounded iteration caps | `plugins/ai-native-team/agents/fleet-orchestrator.md`, `plugins/zen-agents/agents/programmer.md` | `wiki/patterns/bounded-iteration-caps.md` (future) |
| Mandatory learning signal before close | `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md` | (covered in `wiki/patterns/completion-report-protocol.md`) |
| Named security policies | `plugins/zen-agents/agents/orchestrator.md` | `rules/prompt-injection-policy.md`, `rules/dangerous-operations-policy.md`, `rules/degradation-fallback-policy.md` |
| Adversarial / multi-role review | `plugins/adversarial-audit/`, `plugins/triage-team/`, `plugins/review-verdict/` | `wiki/patterns/multi-role-review.md` |
| Per-operation retry+timeout tables | `plugins/zen-agents/agents/scrum-master.md`, `plugins/zen-agents/agents/peer-reviewer.md` | `wiki/patterns/per-operation-retry-tables.md` (future) |
| Completion Report Protocol | `plugins/zen-agents/agents/peer-reviewer.md` + every other zen-agent | `wiki/patterns/completion-report-protocol.md` |
| Preflight dependency checks | `plugins/zen-agents/agents/system-design-author.md` | `wiki/patterns/preflight-dependency-checks.md` |
| Honest-about-limitations inline | `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md` | `rules/degradation-fallback-policy.md` |
| Template tiering / mode-awareness | `plugins/dotnet-dev-kit/skills/mad-tasks/`, `plugins/review-verdict/`, `plugins/pr-review-critic/` | `wiki/patterns/mode-aware-sizing.md` (future) |
| Verified industry alignment | (many) | `wiki/references.md` |

## Plugins to read first (top 10)

If you're implementing MAD.Council and you only read 10 marketplace plugin files, read these:

### 1. `plugins/zen-agents/agents/orchestrator.md`

The most mature orchestrator in the marketplace. Source for all three named cross-cutting policies (prompt-injection, dangerous-ops, degradation). Also the canonical "ORCHESTRATE ONLY — NEVER DO THE WORK YOURSELF" identity text.

**Pull from this:**
- Prompt-injection literal-phrase ban list (rules/prompt-injection-policy.md Rule 1).
- Dangerous-ops 6-category confirmation table (rules/dangerous-operations-policy.md).
- Degradation & Fallback 5 rules (rules/degradation-fallback-policy.md).
- Handoff button frontmatter pattern (for Phase-4 integration).
- "Do what's asked, not what you think should happen" rule.

### 2. `plugins/sfi-dev-toolkit/agents/sfi-dev-orchestrator.md`

Routing orchestrator with deep learning-signal integration. Grounds run_id, remediation-review, ALAS.

**Pull from this:**
- `run_id` GUID generation + propagation (wiki/patterns/run-id-correlation.md).
- "Router not remediator" identity strength.
- Graceful fallback 4-option menu (Read TSG / Analyze codebase / Portal automate / Connect).
- Honest-about-limitations "endpoints that do NOT exist" list.
- Mandatory-signal-before-close checkpoint.

### 3. `plugins/adversarial-audit/agents/` (prosecutor.md, defender.md, judge.md)

Court-metaphor 3-role adversarial review. Canonical implementation of the binding-verdict pattern.

**Pull from this:**
- Prosecutor/Defender/Judge role definitions (alternate naming for Council).
- Shared severity rubric with litmus tests (wiki/patterns/multi-role-review.md §5.4).
- Binding verdict types FIX/ACCEPT/ESCALATE/INVESTIGATE.
- Evidence-beats-assertion principle.

### 4. `plugins/triage-team/agents/` (advocate.md, skeptic.md, architect.md)

Construct-focused 3-role review. Same pattern as adversarial-audit but with non-courtroom naming.

**Pull from this:**
- Advocate/Skeptic/Architect role mindsets (canonical for Council roles).
- "Evidence beats assertion" rule (verbatim).
- Tool hierarchy preference (localsearch > Grep > Glob > Read > Bash).

### 5. `plugins/review-verdict/skills/review-verdict/`

Industrial-scale multi-role review with optional 3-model consensus ensemble.

**Pull from this:**
- 3-model ensemble + validator consensus (3/3, 2/3, safe-default fallback).
- YAGNI filter pass.
- Mode-aware sizing (`auto` vs `propose`).
- Spoofing-protected dedup by authenticated identity.
- Platform auto-detection from git remote.
- 4-path PR template auto-detection.

### 6. `plugins/ai-native-team/agents/fleet-orchestrator.md`

4-stage pipeline (plan → implement → test → review) with circuit breakers.

**Pull from this:**
- 3-consecutive-failure circuit breaker pattern.
- Trust-tier ≥700 gating for destructive ops in daemon mode.
- Named failure modes with recovery paths (no-PR-diff, >5000-line-diff, no-release-tags, no-test-framework, tool-failure).
- Docs-only PR auto-approve pattern.
- Quality gates between stages.

### 7. `plugins/zen-agents/agents/system-design-author.md`

Canonical preflight-dependency-checks implementation.

**Pull from this:**
- 6-row preflight table with Stop / Warn+Skip / Warn+Auto-install actions.
- Preflight report rendering with ✅ ⚠️ ❌ icons.
- Two-round review cycle (DESIGN_R1 → addressed → DESIGN_R2).
- Non-destructive review (always creates a COPY, never modifies original).
- 3-label MS Learn alignment (Supported / Conditional / Conflicts) with Alternate Designs.

### 8. `plugins/dotnet-dev-kit/skills/` (mad-spec, mad-plan, mad-tasks)

The MAD workflow source. Spec-first discipline with adaptive template tiering.

**Pull from this:**
- Spec artifact structure (FR-IDs, NEEDS_CLARIFICATION markers, success criteria).
- Plan artifact (Phase 0 research pipeline, contract integrity gate, C4 diagrams).
- Tasks artifact with MINIMAL/STANDARD/FULL tiers.
- Spec → plan → tasks verification gates.

### 9. `plugins/a2a-starship/skills/` (shipbridge-setup, crewcommunicator-setup)

Concrete A2A protocol implementation in .NET 10.

**Pull from this:**
- A2A Ship Bridge + Crew Communicator topology.
- HTTPS:8222 default + HTTP fallback for corporate.
- Agent Card advertisement via `--name` + `--description`.
- MCP-stdio bridge pattern between Claude Code session and A2A.

### 10. `plugins/zen-agents/agents/scrum-master.md`

Canonical per-operation retry table + batch-size gates.

**Pull from this:**
- 4-column retry+timeout table format (Operation / Max Retries / Timeout / On Failure).
- Batch-size confirmation gates (MUST NOT create >20 work items without user confirmation).
- Loop prevention (3-consecutive-failure stop).
- Partial-context reporting in Completion Reports.

## Secondary plugins worth reading (top 20)

If you have time beyond the top 10:

11. `plugins/zen-agents/agents/orchestrator.md` "handoffs" frontmatter — UI-level multi-agent handoff buttons.
12. `plugins/pr-review-critic/agents/pr-review-critic.md` — 0-100 quantified merge readiness score (6 dimensions).
13. `plugins/review-swarm/skills/review-swarm/SKILL.md` — Inspector/Breaker/Exploiter 3-role parallel swarm with `--fast` and `--project-skill` flags.
14. `plugins/ai-security-pack/agents/critic.md` — Pattern-verification pass ("flag both code AND the flawed pattern it follows").
15. `plugins/agent-orchestrator/agents/orchestrator.md` — Meta-orchestrator with 10-3-1 scoring rubric (name + keyword + domain).
16. `plugins/retro-bar-raiser/agents/retro-bar-raiser.md` — 6-dim weighted retrospective scoring (Five Whys=25%).
17. `plugins/retro-action-items/skills/retro-action-items/SKILL.md` — Dynamic column mapping (don't hardcode UI labels); dual-auth fallback chain.
18. `plugins/retro-ai/skills/retro-ai/SKILL.md` — 5-source incident reconciliation; privacy-preserving synthesis.
19. `plugins/test-sentinel/agents/test-sentinel.md` — YAML I/O schema in frontmatter; Unix-exit-code result model (4 states).
20. `plugins/sfi-dev-toolkit/skills/remediation-review/SKILL.md` — Honest learning signal capture; 1-5 scoring with deliberately-low-scores valued over inflated 5s.

## Plugins for specific concerns

### For security / threat modeling

- `plugins/zen-agents/agents/security-manager.md` — STRIDE lean-output format; Critical/High severity-filtered findings.
- `plugins/ai-security-pack/skills/security-reviews/SKILL.md` — workflow that invokes ai-starter-pack's threat-modeler.
- `plugins/ai-native-team/agents/iac-validator.md` — multi-format (Bicep / Terraform / ARM / GHA / Docker) validator with never-weaken-security MUST-NOTs.

### For test strategy

- `plugins/test-sentinel/` — 0→95% coverage single-session orchestrator.
- `plugins/ai-test-agent/` — 6-agent SAP testing platform with entry-point routing.
- `plugins/ai-native-team/agents/test-generator.md` — framework-inference (Jest/pytest/xUnit); happy/edge/error path categorization.

### For retro / learning

- Three retro plugins as reference for different scopes (ADO retros / ICM incidents / PIR review).
- `plugins/agent-native-toolkit/agents/content-quality-loop.md` — assess → fix → retest loop up to 3 iterations.
- `plugins/session-learnings/skills/session-learnings/SKILL.md` — MEMORY.md-as-config-overlay pattern.

### For migration / modernization

- `plugins/sfi-dev-toolkit/skills/` (38+ skills) — the biggest migration-skill family; MISE, Entra, NSP migrations.
- `plugins/server-migration/skills/develop/SKILL.md` — dual-mode workflow (develop: vs just fix:); 4 named verification rules.
- `plugins/typescript-updater/` — feature-flag phase selection; baseline-then-migrate; sessionId propagation.

### For team / multi-agent coordination

- `plugins/zen-agents/` — 9-role SDLC-complete team (prd-author, design-author, design-reviewer, scrum-master, programmer, peer-reviewer, security-manager, feedback-collector, orchestrator).
- `plugins/ai-native-team/skills/fleet-orchestration/SKILL.md` — 16-agent bundled fleet with trigger-phrase routing.
- `plugins/ai-essentials/` — 5-role guardrailed ensemble (architect/developer/security/compliance/writer).

## The 13 confirmed industry gaps

Documented at `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md`. None of these are in the marketplace; MAD.Council addresses some and defers others.

| Gap | MAD.Council status |
|---|---|
| A2A Agent Card format | §6.1 addresses (see CHK-024 for discovery-mechanism decision) |
| STRIDE → ASTRIDE extension | §8.4 uses classic 6; ASTRIDE deferred to Phase 5 |
| 48-hour retro trigger | Not in scope (channels don't have fixed incident cadence) |
| Commit signature verification | Out of scope (runtime coordination, not git integrity) |
| 3-tier autonomy taxonomy | Inherits fleet-orchestrator numeric trust-tier; taxonomy deferred |
| Per-agent max_tool_calls budget | §10.5 partial — bounded iteration caps + rate limits |
| LangGraph replanner node | Implicit via §5.8 review-and-fix loop |
| "Start simple, evolve" capability ladder | §3 Architecture's layer independence IS the ladder |
| 3-layer memory (MEMORY+USER+SKILL) | Deferred (relies on host Claude Code MEMORY.md) |
| W3C/ISO session-artifact ontologies | Deferred (Phase 5 potential) |
| SQLite snapshot/rollback state | **Rejected** (§2 Non-Goals — breaks filesystem trust) |
| 100-line spec archival threshold | Thread-level max-100-message nudge (§7.4) |
| Behavioral-equivalence consensus | Deferred (text-similarity consensus in §5.6 for now) |

## Pros (of marketplace-as-source)

- **138 HIGH-confidence patterns already validated** across 10 iterations of review.
- **Diversity of implementation** — 630 plugins, many approaches per concern — lets you pick the best fit.
- **Local** — the marketplace is on the same machine; no external deps.
- **Runnable** — marketplace skills are executable, not just design docs.
- **Traceability** — every MAD decision points back to a specific marketplace pattern file.

## Cons

- **Scale makes survey hard.** 2651 skills is not readable start-to-finish. The CHECKLIST is the distillation but still ~500 lines.
- **Pattern drift.** Two plugins implementing the same pattern may diverge in details (exact severity rubric, exact retry counts). MAD.Council picks one variant each; the marketplace shows the variance.
- **Stale plugins.** Some plugins haven't been updated in months; their patterns may not reflect current Claude Code behavior.
- **Quality variance.** Most plugins are high-quality; a few are prototype-grade. Read the CHECKLIST's "confirmed HIGH" list to avoid the ones that surfaced issues during review.

## Do / Don't

**Do**:

- **Read the top 10 before implementing.** Copy patterns verbatim where they fit.
- **Cite CHECKLIST pattern numbers** in MAD code — they're stable references.
- **Prefer verbatim-lift over re-authoring.** If zen-agents has the exact policy text you need, lift it (with attribution).
- **When two plugins disagree, pick the one with more downstream adoption.** Usually zen-agents or sfi-dev-toolkit.
- **Flag pattern drift in `_review-checklist.md`** when you see it.

**Don't**:

- **Don't re-derive patterns the marketplace already solved.** Look first.
- **Don't assume a plugin is current** without checking its `plugin.json` version + recent commits.
- **Don't copy-paste without attribution** — the marketplace is the source of truth; drifting copies create confusion.
- **Don't over-index on one plugin.** The 14 cross-cutting patterns are cross-cutting because multiple plugins converged on them.

## How MAD.Council uses this implementation-group

**Every rule and wiki pattern in MAD is attributed to at least one marketplace plugin.** The tree:

```
MAD/rules/prompt-injection-policy.md         ← zen-agents/orchestrator.md
MAD/rules/dangerous-operations-policy.md     ← zen-agents/orchestrator.md
MAD/rules/degradation-fallback-policy.md     ← zen-agents/orchestrator.md + fleet-orchestrator
MAD/rules/stride-threat-model.md             ← zen-agents/security-manager.md + marketplace review
MAD/rules/verification-protocol.md           ← server-migration/develop/SKILL.md
MAD/rules/orchestrator-identity.md           ← zen-agents/orchestrator.md + sfi-dev-orchestrator.md
MAD/rules/minimum-change.md                  ← server-migration/develop + zen-agents/programmer
MAD/rules/concurrency-safety.md              ← Channels v1 + mad.council.a2a.md
MAD/wiki/patterns/orchestrator-worker.md     ← fleet-orchestrator + zen-agents + sfi-dev + agent-orchestrator
MAD/wiki/patterns/multi-role-review.md       ← adversarial-audit + triage-team + review-verdict
MAD/wiki/patterns/run-id-correlation.md      ← sfi-dev-orchestrator + typescript-updater
MAD/wiki/patterns/circuit-breakers.md        ← fleet-orchestrator + zen-agents/programmer
MAD/wiki/patterns/preflight-dependency-checks.md ← zen-agents/system-design-author + peer-reviewer
MAD/wiki/patterns/completion-report-protocol.md  ← zen-agents (all 9 roles)
```

When writing the skills/ folder (iter 7-8), each SKILL.md will similarly cite ≥1 marketplace source.

## References

- **CHECKLIST (local)** — `C:\Users\tonym\.claude\loop-scratch\skills-review\CHECKLIST.md` — 138 patterns, 13 gaps.
- **Plugin marketplace root** — `C:\Users\tonym\Repos\playground-main\plugins\`.
- **Plugin-by-plugin index** — `C:\Users\tonym\Repos\playground-main\plugins\*\README.md` (one per plugin).
- Anthropic "Building Effective Agents" — https://www.anthropic.com/research/building-effective-agents (external).

## Related wiki entries

- `wiki/references.md` §13 "Internal" — canonical path to the CHECKLIST.
- `wiki/patterns/` (all entries) — each cites marketplace plugins as source.
- `rules/` (all entries) — each cites the zen-agents source where applicable.
- `wiki/implementations/anthropic-claude-code.md` — the runtime these plugins execute on.

## Drift & maintenance

**Top-N reading lists** ("top 10" / "top 20" / "the 14 cross-cutting patterns") are **curated snapshots as of the Last-reviewed date above**, not live rankings. The marketplace accepts new plugins on a rolling basis and existing plugins evolve — any ranking here is guaranteed-stale the day after it was written. Use these lists as a starting point for reading, not an authority on "what's best right now."

**Re-review cadence:** refresh annually or any time the source CHECKLIST is rebuilt — whichever comes first. When re-reviewing, update:

1. The **Last verified** date at the top of this file.
2. Any plugin whose path changed (`plugins/<old-name>/` → `plugins/<new-name>/`).
3. The **14 cross-cutting patterns table** — add patterns that have become dominant; remove patterns that have faded.
4. The **Drift & maintenance** block below to log what shifted.

**Change log:**

- 2026-04-17 — iter 4 initial compilation; iter 19 added drift/maintenance section (CHK-030).
- `wiki/implementations/a2a.md` — how `plugins/a2a-starship/` bridges marketplace plugins to external A2A agents.
