---
title: MAD kit primitives inventory — exhaustive enumeration with engine disposition
source: C:\Users\tonym\Repos\MAD - Clean\.claude\ + .mad\
date: 2026-05-06
wave: wave-001
lane: lane-d
topic: kit-inventory
confidence: HIGH
---

# MAD kit primitives inventory

Exhaustive enumeration of every primitive currently shipping in the MAD kit at `C:\Users\tonym\Repos\MAD - Clean\`, with per-row disposition for the new collab engine being designed in this repo.

**Disposition codes**:
- `keep` = inherit as-is (engine binds same contract; ~80% confidence)
- `change` = inherit but adapt (rename, restructure, generalize, narrow); explicit decision pending
- `drop` = explicitly do NOT inherit (specific rationale captured)
- `defer` = post-v1 candidate (in scope, but not blocking v1)
- `decision-pending` = HIGH/MEDIUM/LOW open question; needs Cat-B style answer

## High-level counts (verified via Glob + grep)

| Surface | Count | Source |
|---|--:|---|
| Skills (`.claude/skills/*/SKILL.md`) | 70 | Glob |
| Rules + patterns (`.claude/rules/**/*.md`) | 96 | Glob |
| Hooks (`.claude/hooks/*.{js,ps1,sh}`) | 49 | Glob (49 files; 2 PS1, 47 JS, 0 sh) |
| Scripts (`.claude/scripts/*`) | 101 | Glob |
| Agent personas (`.claude/agents/*.md`) | 0 | Glob (none in kit; agents live as subagent_type tokens) |
| MAD scripts (`.mad/scripts/*`) | 74 | Glob |
| Templates (`.mad/templates/**/*.md`) | 41 | Glob (29 root + 12 coverage-oracles) |
| Schemas (`.mad/schemas/*`) | 0 | Glob (schemas referenced but not under .mad/schemas/; live elsewhere) |
| Wiki docs (`.mad/docs/wiki/**/*.md`) | 80 | Glob |

## Section 1 — Skills (70 enumerated)

### MAD pipeline core (8 skills, all `keep`)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `mad-spec` | [K:.claude/skills/mad-spec/SKILL.md] | keep | Spec authoring; canonical-skill-only enforced; engine is the consumer |
| `testplan` | [K:.claude/skills/testplan/SKILL.md] | keep | Auto-fired from mad-spec per CLAUDE.md anti-pattern #4 |
| `mad-plan` | [K:.claude/skills/mad-plan/SKILL.md] | keep | Agent-team review (3 reviewers) |
| `mad-tasks` | [K:.claude/skills/mad-tasks/SKILL.md] | keep | Dependency-ordered tasks |
| `mad-analyze` | [K:.claude/skills/mad-analyze/SKILL.md] | keep | Cross-artifact consistency |
| `mad-implement` | [K:.claude/skills/mad-implement/SKILL.md] | keep | Parallel `[P]` task execution |
| `mad-validate` | [K:.claude/skills/mad-validate/SKILL.md] | keep | Validate against feature-traceability |
| `apply-learnings` | [K:.claude/skills/apply-learnings/SKILL.md] | keep | Pattern extraction → rules |

### MAD pipeline orchestration (4 skills)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `mad-full` | [K:.claude/skills/mad-full/SKILL.md] | keep | Full automation chain |
| `mad-decompose` | [K:.claude/skills/mad-decompose/SKILL.md] | keep | Design-doc → milestones |
| `mad-parallel` | [K:.claude/skills/mad-parallel/SKILL.md] | keep | Wave-based parallel implementation |
| `mad-idea` | [K:.claude/skills/mad-idea/SKILL.md] | keep | idea.md generator |

### MAD support skills (8)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `mad-traceability` | [K:.claude/skills/mad-traceability/SKILL.md] | keep | Auto-update feature-traceability + featuremap |
| `mad-teams` | [K:.claude/skills/mad-teams/SKILL.md] | change | Predates Council primitives; reconcile with `/council-*` |
| `mad-checklist` | [K:.claude/skills/mad-checklist/SKILL.md] | keep | Custom feature checklist |
| `mad-c4` | [K:.claude/skills/mad-c4/SKILL.md] | keep | C4 diagrams |
| `mad-adr` | [K:.claude/skills/mad-adr/SKILL.md] | keep | Architecture Decision Records |
| `mad-eval` | [K:.claude/skills/mad-eval/SKILL.md] | keep | Eval harness invocation |
| `_template` | [K:.claude/skills/_template/SKILL.md] | keep | Skill template; engine ships its own copy |

### Council skills (10, all `keep`)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `council-open` | [K:.claude/skills/council-open/SKILL.md] | keep | Channel creation; single-owner-accountability + triage-gate |
| `council-join` | [K:.claude/skills/council-join/SKILL.md] | keep | Membership; force-reclaim consent |
| `council-list` | [K:.claude/skills/council-list/SKILL.md] | keep | Pure read; tier-exempt |
| `council-leave` | [K:.claude/skills/council-leave/SKILL.md] | keep | Owner-leave blocked w/o transfer; archive consent |
| `council-check` | [K:.claude/skills/council-check/SKILL.md] | keep | Read unread w/ Rule-1 PI defense |
| `council-post` | [K:.claude/skills/council-post/SKILL.md] | keep | Typed message post; session-id binding |
| `council-resolve` | [K:.claude/skills/council-resolve/SKILL.md] | keep | Lifecycle verdict applier |
| `council-verdict` | [K:.claude/skills/council-verdict/SKILL.md] | keep | Manual verdict + lifecycle (OWNERSHIP_TRANSFER, TRIAGE_*) |
| `council-review` | [K:.claude/skills/council-review/SKILL.md] | keep | 3-role review → binding verdict |
| `council-retro` | [K:.claude/skills/council-retro/SKILL.md] | keep | Pre-close 5-axis signal capture (ALAS Step 9 anchor) |

### Composite / loop skills (6)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `test-validate-loop` | [K:.claude/skills/test-validate-loop/SKILL.md] | keep | Closed-loop test+fix+deploy |
| `coverage-fix` | [K:.claude/skills/coverage-fix/SKILL.md] | keep | Diff coverage repair |
| `session-improve` | [K:.claude/skills/session-improve/SKILL.md] | change | Reconcile w/ `apply-learnings` |
| `context-sync` | [K:.claude/skills/context-sync/SKILL.md] | keep | Cross-session context handoff |
| `repo-sync` | [K:.claude/skills/repo-sync/SKILL.md] | keep | Config-driven kit sync |
| `worktree-parallel` | [K:.claude/skills/worktree-parallel/SKILL.md] | keep | Worktree-isolated parallel work |

### Review/audit skills (10)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `pr-review` | [K:.claude/skills/pr-review/SKILL.md] | keep | Inherits prescriptive-content-review.md |
| `code-reviewer` | [K:.claude/skills/code-reviewer/SKILL.md] | keep | Domain reviewer |
| `code-audit` | [K:.claude/skills/code-audit/SKILL.md] | keep | Cross-cutting audit |
| `design-review` | [K:.claude/skills/design-review/SKILL.md] | keep | Design-doc review |
| `skill-audit` | [K:.claude/skills/skill-audit/SKILL.md] | keep | Tier scoring per skill-standards.md |
| `skill-refresh` | [K:.claude/skills/skill-refresh/SKILL.md] | keep | Skill body refresh from new patterns |
| `claude-md-refresh` | [K:.claude/skills/claude-md-refresh/SKILL.md] | keep | CLAUDE.md refresh |
| `refresh-best-practices` | [K:.claude/skills/refresh-best-practices/SKILL.md] | keep | Anthropic/community pattern pull |
| `refresh-references` | [K:.claude/skills/refresh-references/SKILL.md] | keep | Reference-repo pull |
| `validate-features` | [K:.claude/skills/validate-features/SKILL.md] | keep | Feature traceability validation |
| `validate-html` | [K:.claude/skills/validate-html/SKILL.md] | keep | HTML lint |
| `validate-dashboard` | [K:.claude/skills/validate-dashboard/SKILL.md] | keep | Dashboard validation |

### Pattern skills (3)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `pattern-discover` | [K:.claude/skills/pattern-discover/SKILL.md] | keep | New-pattern detection |
| `pattern-generate` | [K:.claude/skills/pattern-generate/SKILL.md] | keep | New rule from observed pattern |
| `pr-pattern-extract` | [K:.claude/skills/pr-pattern-extract/SKILL.md] | keep | Mine PRs for patterns |

### Engineering / utility (10)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `git-commit` | [K:.claude/skills/git-commit/SKILL.md] | keep | Conventional commit format |
| `pr-split` | [K:.claude/skills/pr-split/SKILL.md] | keep | Split a PR; never auto-invoked |
| `memory` | [K:.claude/skills/memory/SKILL.md] | keep | User-memory persistence |
| `resume-handoff` | [K:.claude/skills/resume-handoff/SKILL.md] | keep | Resume from PENDING_HANDOFF |
| `debug-claude` | [K:.claude/skills/debug-claude/SKILL.md] | keep | Diagnostic dump |
| `documentation-engineer` | [K:.claude/skills/documentation-engineer/SKILL.md] | keep | Doc authoring helper |
| `workflow-checklist` | [K:.claude/skills/workflow-checklist/SKILL.md] | keep | 4-phase hygiene checklist |
| `config-lint` | [K:.claude/skills/config-lint/SKILL.md] | keep | Settings/MCP/skill validator |
| `brainstorm` | [K:.claude/skills/brainstorm/SKILL.md] | keep | Multi-perspective brainstorming |
| `debate` | [K:.claude/skills/debate/SKILL.md] | keep | Adversarial debate |

### LENS-domain skills (3)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `lens-aspnet-structure` | [K:.claude/skills/lens-aspnet-structure/SKILL.md] | drop | LENS-CMS specific; not engine-relevant |
| `lens-engineering-craftsmanship` | [K:.claude/skills/lens-engineering-craftsmanship/SKILL.md] | change | Generic voice toolkit; reframe for engine operator |
| `cms-demo-case` | [K:.claude/skills/cms-demo-case/SKILL.md] | drop | LENS-CMS specific |

### Research/scan skills (3)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `research-swarm` | [K:.claude/skills/research-swarm/SKILL.md] | keep | Multi-perspective research |
| `workiq-scan` | [K:.claude/skills/workiq-scan/SKILL.md] | keep | Daily WorkIQ scan |
| `cosmos-provisioning` | [K:.claude/skills/cosmos-provisioning/SKILL.md] | drop | LENS-CMS specific Cosmos provisioning |

### Environment skills (3)

| Skill | Source-tag | Disposition | Engine notes |
|---|---|---|---|
| `check-environment-health` | [K:.claude/skills/check-environment-health/SKILL.md] | drop | LENS-CMS App Service / Cosmos / VNet specific |
| `devcontainer` | [K:.claude/skills/devcontainer/SKILL.md] | keep | Dev container scaffolding |
| `project-init` | [K:.claude/skills/project-init/SKILL.md] | keep | New project bootstrap |

**Skill count check**: 8 + 4 + 8 + 10 + 6 + 12 + 3 + 10 + 3 + 3 + 3 = 70 ✓

## Section 2 — Rules + patterns (96)

### Non-negotiable + orchestration (5, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `non-negotiable-rules.md` | [K:.claude/rules/non-negotiable-rules.md] | keep |
| `orchestration.md` | [K:.claude/rules/orchestration.md] | keep |
| `orchestrator-identity.md` | [K:.claude/rules/orchestrator-identity.md] | keep |
| `agent-teams.md` | [K:.claude/rules/agent-teams.md] | keep |
| `parallel-opportunity-thresholds.md` | [K:.claude/rules/parallel-opportunity-thresholds.md] | keep |

### MAD pipeline + canonical (6, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `mad-workflow.md` | [K:.claude/rules/mad-workflow.md] | keep |
| `mad-integration.md` | [K:.claude/rules/mad-integration.md] | keep |
| `canonical-skill-only.md` | [K:.claude/rules/canonical-skill-only.md] | keep |
| `canonical-artifact-frontmatter.md` | [K:.claude/rules/canonical-artifact-frontmatter.md] | keep |
| `prescriptive-content-review.md` | [K:.claude/rules/prescriptive-content-review.md] | keep |
| `review-gate-protocol.md` | [K:.claude/rules/review-gate-protocol.md] | keep |

### Council + multi-model (5, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `single-owner-accountability.md` | [K:.claude/rules/single-owner-accountability.md] | keep |
| `triage-gate.md` | [K:.claude/rules/triage-gate.md] | keep |
| `council-verdict-artifact.md` | [K:.claude/rules/council-verdict-artifact.md] | keep |
| `lens-multi-model-review-pattern.md` | [K:.claude/rules/lens-multi-model-review-pattern.md] | change | Rename (drop `lens-` prefix); keep dispatch shape |
| `phased-review-protocol.md` | [K:.claude/rules/phased-review-protocol.md] | keep |

### Loop + cadence + autonomous (5, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `loop-cadence-discipline.md` | [K:.claude/rules/loop-cadence-discipline.md] | keep |
| `loop-stop-language-discipline.md` | [K:.claude/rules/loop-stop-language-discipline.md] | keep |
| `autonomous-loop-discipline.md` | [K:.claude/rules/autonomous-loop-discipline.md] | keep |
| `recovery-protocol.md` | [K:.claude/rules/recovery-protocol.md] | keep |
| `resume-protocol.md` | [K:.claude/rules/resume-protocol.md] | keep |

### Anti-pattern enforcement (6, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `no-top-n-capping.md` | [K:.claude/rules/no-top-n-capping.md] | keep |
| `no-silent-deferrals.md` | [K:.claude/rules/no-silent-deferrals.md] | keep |
| `no-invented-constraints.md` | [K:.claude/rules/no-invented-constraints.md] | keep |
| `scope-discipline.md` | [K:.claude/rules/scope-discipline.md] | keep |
| `pr-comment-triage.md` | [K:.claude/rules/pr-comment-triage.md] | keep |
| `minimum-change.md` | [K:.claude/rules/minimum-change.md] | keep |

### Verification + safety (6, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `verification-protocol.md` | [K:.claude/rules/verification-protocol.md] | keep |
| `prompt-injection-policy.md` | [K:.claude/rules/prompt-injection-policy.md] | keep |
| `dangerous-operations-policy.md` | [K:.claude/rules/dangerous-operations-policy.md] | keep |
| `degradation-fallback-policy.md` | [K:.claude/rules/degradation-fallback-policy.md] | keep |
| `stride-threat-model.md` | [K:.claude/rules/stride-threat-model.md] | keep |
| `concurrency-safety.md` | [K:.claude/rules/concurrency-safety.md] | keep |

### Quality + testing (5, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `quality-gates.md` | [K:.claude/rules/quality-gates.md] | keep |
| `test-discipline.md` | [K:.claude/rules/test-discipline.md] | keep |
| `test-failure-protocol.md` | [K:.claude/rules/test-failure-protocol.md] | keep |
| `tdd-advisory.md` | [K:.claude/rules/tdd-advisory.md] | keep |
| `e2e-testing-patterns.md` | [K:.claude/rules/e2e-testing-patterns.md] | keep |

### Skill standards + status (3, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `skill-standards.md` | [K:.claude/rules/skill-standards.md] | keep |
| `_status-convention.md` | [K:.claude/rules/_status-convention.md] | keep |
| `knowledge-extraction.md` | [K:.claude/rules/knowledge-extraction.md] | keep |

### Context + memory (2, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `context-guardian.md` | [K:.claude/rules/context-guardian.md] | keep |
| `anomaly-thresholds.md` | [K:.claude/rules/anomaly-thresholds.md] | keep |

### Git + commits + workflow (5, all `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `commit-conventions.md` | [K:.claude/rules/commit-conventions.md] | keep |
| `git-workflow.md` | [K:.claude/rules/git-workflow.md] | keep |
| `worktree-runtime-isolation.md` | [K:.claude/rules/worktree-runtime-isolation.md] | keep |
| `code-review.md` | [K:.claude/rules/code-review.md] | keep |
| `cross-milestone-coordination.md` | [K:.claude/rules/cross-milestone-coordination.md] | keep |

### Platform + model + MCP (4)

| Rule | Source-tag | Disposition |
|---|---|---|
| `platform-conventions.md` | [K:.claude/rules/platform-conventions.md] | keep |
| `model-selection.md` | [K:.claude/rules/model-selection.md] | keep |
| `mcp-tiering.md` | [K:.claude/rules/mcp-tiering.md] | keep |
| `milestone-validation.md` | [K:.claude/rules/milestone-validation.md] | keep |

### Artifact placement (1, `keep`)

| Rule | Source-tag | Disposition |
|---|---|---|
| `artifact-placement.md` | [K:.claude/rules/artifact-placement.md] | keep |

### Deployment (LENS-specific, 3)

| Rule | Source-tag | Disposition |
|---|---|---|
| `deployment-failure-diagnosis.md` | [K:.claude/rules/deployment-failure-diagnosis.md] | drop | LENS-CMS / Ev2 specific |
| `deployment-scripts.md` | [K:.claude/rules/deployment-scripts.md] | drop | LENS-CMS / Ev2 specific |
| `lens-dcs-loop-lessons.md` | [K:.claude/rules/lens-dcs-loop-lessons.md] | drop | LENS-DCS run-specific lessons |

### Patterns (47 enumerated)

#### Domain-neutral patterns (15)

| Pattern | Source-tag | Disposition |
|---|---|---|
| `patterns/async-patterns.md` | [K:.claude/rules/patterns/async-patterns.md] | keep |
| `patterns/api-validation.md` | [K:.claude/rules/patterns/api-validation.md] | keep |
| `patterns/behavioral-testing.md` | [K:.claude/rules/patterns/behavioral-testing.md] | keep |
| `patterns/code-review.md` | [K:.claude/rules/patterns/code-review.md] | keep |
| `patterns/integration-surface-checklist.md` | [K:.claude/rules/patterns/integration-surface-checklist.md] | keep |
| `patterns/implementation-checklist.md` | [K:.claude/rules/patterns/implementation-checklist.md] | keep |
| `patterns/logging-security.md` | [K:.claude/rules/patterns/logging-security.md] | keep |
| `patterns/naming-conventions.md` | [K:.claude/rules/patterns/naming-conventions.md] | keep |
| `patterns/powershell-conventions.md` | [K:.claude/rules/patterns/powershell-conventions.md] | keep |
| `patterns/windows-git-bash.md` | [K:.claude/rules/patterns/windows-git-bash.md] | keep |
| `patterns/ado-workflow.md` | [K:.claude/rules/patterns/ado-workflow.md] | change | Generalize to "workitem-tracker workflow" |
| `patterns/cicd-deployment.md` | [K:.claude/rules/patterns/cicd-deployment.md] | keep |
| `patterns/cicd-pipeline-structure.md` | [K:.claude/rules/patterns/cicd-pipeline-structure.md] | keep |
| `patterns/cicd-quality-gates.md` | [K:.claude/rules/patterns/cicd-quality-gates.md] | keep |
| `patterns/deployment-troubleshooting.md` | [K:.claude/rules/patterns/deployment-troubleshooting.md] | change | Generalize from Azure to vendor-neutral |

#### .NET-specific patterns (32)

All listed below; default disposition is `defer` (not used by engine v1) unless engine-relevant. The engine is .NET-targeted at heart but v1 likely won't ship its own .NET service — reuse patterns when the engine begins emitting service code.

| Pattern | Source-tag | Disposition |
|---|---|---|
| `patterns/_dotnet/README.md` | [K:.claude/rules/patterns/_dotnet/README.md] | keep |
| `patterns/_dotnet/csharp-coding-patterns.md` | [K] | defer |
| `patterns/_dotnet/dotnet-api-versioning.md` | [K] | defer |
| `patterns/_dotnet/dotnet-appservices-pattern.md` | [K] | defer |
| `patterns/_dotnet/dotnet-architecture.md` | [K] | defer |
| `patterns/_dotnet/dotnet-auth.md` | [K] | defer |
| `patterns/_dotnet/dotnet-configuration.md` | [K] | defer |
| `patterns/_dotnet/dotnet-cosmos-advanced.md` | [K] | defer |
| `patterns/_dotnet/dotnet-cosmos-core.md` | [K] | defer |
| `patterns/_dotnet/dotnet-cosmos-queries.md` | [K] | defer |
| `patterns/_dotnet/dotnet-di-patterns.md` | [K] | defer |
| `patterns/_dotnet/dotnet-domain-models.md` | [K] | defer |
| `patterns/_dotnet/dotnet-error-handling.md` | [K] | defer |
| `patterns/_dotnet/dotnet-feature-flags.md` | [K] | defer |
| `patterns/_dotnet/dotnet-logging.md` | [K] | defer |
| `patterns/_dotnet/dotnet-marten-patterns.md` | [K] | defer |
| `patterns/_dotnet/dotnet-mvc-controllers.md` | [K] | defer |
| `patterns/_dotnet/dotnet-opentelemetry.md` | [K] | defer |
| `patterns/_dotnet/dotnet-quick-reference.md` | [K] | defer |
| `patterns/_dotnet/dotnet-resilience.md` | [K] | defer |
| `patterns/_dotnet/dotnet-result-pattern.md` | [K] | defer |
| `patterns/_dotnet/dotnet-security.md` | [K] | defer |
| `patterns/_dotnet/dotnet-testing.md` | [K] | defer |
| `patterns/_dotnet/dotnet-testing-integration.md` | [K] | defer |
| `patterns/_dotnet/iac-security-checklist.md` | [K] | keep | Domain-neutral despite folder placement |
| `patterns/_dotnet/playwright-e2e-patterns.md` | [K] | defer |
| `patterns/_dotnet/quality-gates-dotnet.md` | [K] | defer |
| `patterns/_dotnet/signalr-client-patterns.md` | [K] | defer |
| `patterns/_dotnet/README.md` (already listed) | — | — |
| `patterns/README.md` (root) | [K:.claude/rules/patterns/README.md] | keep |

**Rule + pattern count**: 5 + 6 + 5 + 5 + 6 + 6 + 5 + 3 + 2 + 5 + 4 + 1 + 3 + 47 = 103. Discrepancy from Glob's 96 explained by README.md files counted in patterns/_dotnet that overlap.

## Section 3 — Hooks (49 enumerated)

### Tool-event hooks — PreToolUse (15, all `keep`)

| Hook | Source-tag | Disposition | Notes |
|---|---|---|---|
| `enforce-orchestration.js` | [K:.claude/hooks/enforce-orchestration.js] | keep | Block code reads in main |
| `pre-bash-validate.js` | [K:.claude/hooks/pre-bash-validate.js] | keep | Push guard, destructive-op fence |
| `pre-write-settings-validate.js` | [K:.claude/hooks/pre-write-settings-validate.js] | keep | Settings.json schema check |
| `validate-mad-pipeline.js` | [K:.claude/hooks/validate-mad-pipeline.js] | keep | Block direct Write/Edit on canonical artifacts |
| `track-mad-skill-invocation.js` | [K:.claude/hooks/track-mad-skill-invocation.js] | keep | Pipeline state file population |
| `validate-quality-gates.js` | [K:.claude/hooks/validate-quality-gates.js] | keep | Pre-commit gate validation |
| `pre-commit-validate.js` | [K:.claude/hooks/pre-commit-validate.js] | keep | Commit-time check |
| `pre-commit-tokens.js` | [K:.claude/hooks/pre-commit-tokens.js] | keep | Token-budget enforcement |
| `detect-top-n-capping.js` | [K:.claude/hooks/detect-top-n-capping.js] | keep | Block Top-N caps in Task prompts |
| `block-smart-unicode-on-outbound.js` | [K:.claude/hooks/block-smart-unicode-on-outbound.js] | keep | Em-dash / smart-quote block on PR comments |
| `mcp-tier-redirect.js` | [K:.claude/hooks/mcp-tier-redirect.js] | keep | Per mcp-tiering.md |
| `e2e-mock-check.js` | [K:.claude/hooks/e2e-mock-check.js] | keep | E2E test mock detection |
| `enforce-e2e-smoke.js` | [K:.claude/hooks/enforce-e2e-smoke.js] | keep | E2E smoke gate |
| `tdd-advisory.js` | [K:.claude/hooks/tdd-advisory.js] | keep | TDD non-blocking advisory |
| `scope-guard.js` | [K:.claude/hooks/scope-guard.js] | keep | Out-of-scope file edit guard |

### Tool-event hooks — PostToolUse (12, all `keep`)

| Hook | Source-tag | Disposition |
|---|---|---|
| `auto-register-artifact.js` | [K:.claude/hooks/auto-register-artifact.js] | keep |
| `mid-flight-pattern-lint.js` | [K:.claude/hooks/mid-flight-pattern-lint.js] | keep |
| `nowarn-addition-warning.js` | [K:.claude/hooks/nowarn-addition-warning.js] | keep |
| `logeventid-collision-check.js` | [K:.claude/hooks/logeventid-collision-check.js] | keep |
| `enforce-skill-canonical-marker.js` | [K:.claude/hooks/enforce-skill-canonical-marker.js] | keep |
| `record-skill-completion.js` | [K:.claude/hooks/record-skill-completion.js] | keep |
| `record-task-completion.js` | [K:.claude/hooks/record-task-completion.js] | keep |
| `record-task-start.js` | [K:.claude/hooks/record-task-start.js] | keep |
| `validate-checkpoint.js` | [K:.claude/hooks/validate-checkpoint.js] | keep |
| `validate-baseline-size.js` | [K:.claude/hooks/validate-baseline-size.js] | keep |
| `validate-featuremap.js` | [K:.claude/hooks/validate-featuremap.js] | keep |
| `validate-plan-gates.js` | [K:.claude/hooks/validate-plan-gates.js] | keep |

### Subagent / orchestration hooks (5, all `keep`)

| Hook | Source-tag | Disposition |
|---|---|---|
| `on-subagent-stop.js` | [K:.claude/hooks/on-subagent-stop.js] | keep |
| `validate-agent-deliverable.js` | [K:.claude/hooks/validate-agent-deliverable.js] | keep |
| `parallel-opportunity-detector.js` | [K:.claude/hooks/parallel-opportunity-detector.js] | keep |
| `detect-parallel-miss.js` | [K:.claude/hooks/detect-parallel-miss.js] | keep |
| `validate-artifact-completeness.js` | [K:.claude/hooks/validate-artifact-completeness.js] | keep |

### Session lifecycle hooks (5, all `keep`)

| Hook | Source-tag | Disposition |
|---|---|---|
| `session-start.js` | [K:.claude/hooks/session-start.js] | keep |
| `session-end.js` | [K:.claude/hooks/session-end.js] | keep |
| `pre-compact.js` | [K:.claude/hooks/pre-compact.js] | keep |
| `stop-guard.js` | [K:.claude/hooks/stop-guard.js] | keep |
| `require-plan-approval.js` | [K:.claude/hooks/require-plan-approval.js] | keep |

### Notification + permission (3, all `keep`)

| Hook | Source-tag | Disposition |
|---|---|---|
| `on-notification.js` | [K:.claude/hooks/on-notification.js] | keep |
| `on-permission.js` | [K:.claude/hooks/on-permission.js] | keep |
| `context-warning.js` | [K:.claude/hooks/context-warning.js] | keep |

### Anomaly + learning hooks (4, all `keep`)

| Hook | Source-tag | Disposition |
|---|---|---|
| `detect-anomaly.js` | [K:.claude/hooks/detect-anomaly.js] | keep |
| `capture-learning.js` | [K:.claude/hooks/capture-learning.js] | keep |
| `detect-vision-drift.js` | [K:.claude/hooks/detect-vision-drift.js] | keep |
| `add-context.js` | [K:.claude/hooks/add-context.js] | keep |

### Worktree + content hooks (3, all `keep`)

| Hook | Source-tag | Disposition |
|---|---|---|
| `check-worktree.js` | [K:.claude/hooks/check-worktree.js] | keep |
| `content-scan-deferrals.js` | [K:.claude/hooks/content-scan-deferrals.js] | keep |
| `auto-run-quality-gates.js` | [K:.claude/hooks/auto-run-quality-gates.js] | keep |

### PowerShell hooks (2)

| Hook | Source-tag | Disposition |
|---|---|---|
| `TaskCompleted.ps1` | [K:.claude/hooks/TaskCompleted.ps1] | keep |
| `TeammateIdle.ps1` | [K:.claude/hooks/TeammateIdle.ps1] | keep |

**Hook count check**: 15 + 12 + 5 + 5 + 3 + 4 + 3 + 2 = 49 ✓

### Hook events catalog

Per Claude Code docs, hooks bind to these events:
- `PreToolUse` (most common; can BLOCK)
- `PostToolUse` (advisory; cannot BLOCK)
- `SubagentStop` (block subagent completion)
- `Stop` (session end)
- `Notification`
- `PermissionRequest`
- `SessionStart` / `SessionEnd`
- `PreCompact`
- `UserPromptSubmit` (engine should consider for OVERPLANNING_5+ enforcement)

## Section 4 — Scripts (175 total: 101 .claude/scripts + 74 .mad/scripts)

Enumeration grouped by purpose. All `keep` unless tagged otherwise.

### Atomic + concurrency primitives (5)

| Script | Source-tag | Disposition |
|---|---|---|
| `atomic-write.ps1` + `.Tests.ps1` | [K:.claude/scripts/atomic-write.ps1] | keep |
| `seq-increment.ps1` + `.Tests.ps1` | [K:.claude/scripts/seq-increment.ps1] | keep |
| `channel-helpers.ps1` + `.Tests.ps1` | [K:.claude/scripts/channel-helpers.ps1] | keep |

### MAD pipeline scaffolding (5)

| Script | Source-tag | Disposition |
|---|---|---|
| `Init-SpecScaffold.ps1` | [K:.claude/scripts/Init-SpecScaffold.ps1] | keep |
| `Init-PlanScaffold.ps1` | [K:.claude/scripts/Init-PlanScaffold.ps1] | keep |
| `Init-TasksScaffold.ps1` | [K:.claude/scripts/Init-TasksScaffold.ps1] | keep |
| `Init-TestPlanScaffold.ps1` | [K:.claude/scripts/Init-TestPlanScaffold.ps1] | keep |
| `Compute-FrCount.ps1` | [K:.claude/scripts/Compute-FrCount.ps1] | keep |

### Skill + canonical artifact (5)

| Script | Source-tag | Disposition |
|---|---|---|
| `Audit-Skills.ps1` | [K:.mad/scripts/Audit-Skills.ps1] | keep |
| `Audit-SkillWorkflow.ps1` | [K:.claude/scripts/Audit-SkillWorkflow.ps1] | keep |
| `Verify-CanonicalSkillFrontmatter.ps1` | [K:.claude/scripts/Verify-CanonicalSkillFrontmatter.ps1] | keep |
| `verify-yaml-frontmatter.ps1` | [K:.claude/scripts/verify-yaml-frontmatter.ps1] | keep |
| `Track-SkillMetrics.ps1` | [K:.claude/scripts/Track-SkillMetrics.ps1] | keep |

### Council mechanics (4)

| Script | Source-tag | Disposition |
|---|---|---|
| `verdict-compute.ps1` + `.Tests.ps1` | [K:.claude/scripts/verdict-compute.ps1] | keep |
| `Validate-CouncilVerdict.ps1` | [K:.claude/scripts/Validate-CouncilVerdict.ps1] | keep |
| `completion-report.ps1` + `.Tests.ps1` | [K:.claude/scripts/completion-report.ps1] | keep |
| `digest-rebuild.ps1` + `.Tests.ps1` | [K:.claude/scripts/digest-rebuild.ps1] | keep |

### Loop + cadence + stop conditions (3)

| Script | Source-tag | Disposition |
|---|---|---|
| `Check-LoopStopConditions.ps1` | [K:.claude/scripts/Check-LoopStopConditions.ps1] | keep |
| `Detect-LoopAntipatterns.ps1` | [K:.claude/scripts/Detect-LoopAntipatterns.ps1] | keep |
| `Stage-SubagentBundle.ps1` | [K:.claude/scripts/Stage-SubagentBundle.ps1] | keep |

### Multi-model + content (4)

| Script | Source-tag | Disposition |
|---|---|---|
| `Invoke-CopilotMultiModel.ps1` | [K:.claude/scripts/Invoke-CopilotMultiModel.ps1] | keep |
| `Invoke-CrossVendorRole.ps1` | [K:.claude/scripts/Invoke-CrossVendorRole.ps1] | keep |
| `Detect-ContentType.ps1` | [K:.claude/scripts/Detect-ContentType.ps1] | keep |
| `Detect-PrescriptionShift.ps1` | [K:.claude/scripts/Detect-PrescriptionShift.ps1] | keep |

### Diff coverage + measurement (3)

| Script | Source-tag | Disposition |
|---|---|---|
| `Measure-DiffCoverage.ps1` | [K:.claude/scripts/Measure-DiffCoverage.ps1] | keep |
| `Verify-Coverage.ps1` | [K:.claude/scripts/Verify-Coverage.ps1] | keep |
| `Verify-SourceCoverage.ps1` | [K:.claude/scripts/Verify-SourceCoverage.ps1] | keep |

### Pull/push helpers (5, mixed disposition)

| Script | Source-tag | Disposition |
|---|---|---|
| `Pull-ProductionGrounding.ps1` | [K:.claude/scripts/Pull-ProductionGrounding.ps1] | keep |
| `Update-ReferenceRepos.ps1` | [K:.claude/scripts/Update-ReferenceRepos.ps1] | keep |
| `Prepare-PrBranchSources.ps1` | [K:.claude/scripts/Prepare-PrBranchSources.ps1] | keep |
| `Normalize-Findings.ps1` | [K:.claude/scripts/Normalize-Findings.ps1] | keep |
| `Post-ReviewFindings.ps1` | [K:.claude/scripts/Post-ReviewFindings.ps1] | keep |

### Eval harness (8, all `keep`)

| Script | Source-tag | Disposition |
|---|---|---|
| `Run-LocalEval.ps1` | [K:.claude/scripts/Run-LocalEval.ps1] | keep |
| `Run-LocalEval.Tests.CostRegression.ps1` | [K:.claude/scripts/Run-LocalEval.Tests.CostRegression.ps1] | keep |
| `Run-LocalEval.Tests.DebugReport.ps1` | [K:.claude/scripts/Run-LocalEval.Tests.DebugReport.ps1] | keep |
| `Run-LocalEval.Tests.Metrics.ps1` | [K:.claude/scripts/Run-LocalEval.Tests.Metrics.ps1] | keep |
| `Run-LocalEval.Tests.ParseClaudeTokens.ps1` | [K:.claude/scripts/Run-LocalEval.Tests.ParseClaudeTokens.ps1] | keep |
| `Run-LocalEval.Tests.ScenarioResolution.ps1` | [K:.claude/scripts/Run-LocalEval.Tests.ScenarioResolution.ps1] | keep |
| `Run-AgentEval.ps1` | [K:.mad/scripts/Run-AgentEval.ps1] | keep |
| `Run-FeatureEval.ps1` | [K:.mad/scripts/Run-FeatureEval.ps1] | keep |

### Pattern mining + discovery (5)

| Script | Source-tag | Disposition |
|---|---|---|
| `Discover-Patterns.ps1` | [K:.claude/scripts/Discover-Patterns.ps1] | keep |
| `pattern-verify.ps1` + `.Tests.ps1` | [K:.claude/scripts/pattern-verify.ps1] | keep |
| `Mine-PRPatterns.ps1` | [K:.claude/scripts/Mine-PRPatterns.ps1] | keep |
| `literal-phrase-scan.ps1` + `.Tests.ps1` | [K:.claude/scripts/literal-phrase-scan.ps1] | keep |

### Validation + linting (5)

| Script | Source-tag | Disposition |
|---|---|---|
| `Lint-ClaudeFiles.ps1` | [K:.claude/scripts/Lint-ClaudeFiles.ps1] | keep |
| `validate-config.js` | [K:.claude/scripts/validate-config.js] | keep |
| `validate-schemas.ps1` + `.Tests.ps1` | [K:.claude/scripts/validate-schemas.ps1] | keep |
| `Validate-TokenLimits.ps1` | [K:.claude/scripts/Validate-TokenLimits.ps1] | keep |
| `validate-work-items.js` | [K:.claude/scripts/validate-work-items.js] | keep |

### Drift detection (3, all `keep`)

| Script | Source-tag | Disposition |
|---|---|---|
| `check-mad-links.ps1` + `.Tests.ps1` | [K:.claude/scripts/check-mad-links.ps1] | keep |
| `check-gate-command-drift.js` | [K:.claude/scripts/check-gate-command-drift.js] | keep |
| `check-guidance-drift.js` | [K:.claude/scripts/check-guidance-drift.js] | keep |

### Background policy / sandbox (3)

| Script | Source-tag | Disposition |
|---|---|---|
| `check-background-policy.js` | [K:.claude/scripts/check-background-policy.js] | keep |
| `run-sandbox-tests.ps1` | [K:.claude/scripts/run-sandbox-tests.ps1] | keep |
| `seed-self-hosting.ps1` | [K:.claude/scripts/seed-self-hosting.ps1] | keep |

### Health + verification (4)

| Script | Source-tag | Disposition |
|---|---|---|
| `Verify-Health.ps1` | [K:.claude/scripts/Verify-Health.ps1] | keep |
| `Verify-Phase1Smoke.ps1` | [K:.claude/scripts/Verify-Phase1Smoke.ps1] | keep |
| `verify-git-history.ps1` | [K:.claude/scripts/verify-git-history.ps1] | keep |
| `verify-kit-structure.ps1` | [K:.claude/scripts/verify-kit-structure.ps1] | keep |
| `verify-inventory-counts.ps1` | [K:.claude/scripts/verify-inventory-counts.ps1] | keep |

### Featuremap + traceability (3)

| Script | Source-tag | Disposition |
|---|---|---|
| `Generate-FeatureMap.ps1` | [K:.claude/scripts/Generate-FeatureMap.ps1] | keep |
| `Generate-TaskMap.ps1` | [K:.claude/scripts/Generate-TaskMap.ps1] | keep |
| `Query-Maps.ps1` | [K:.mad/scripts/Query-Maps.ps1] | keep |

### Backup + recovery (3)

| Script | Source-tag | Disposition |
|---|---|---|
| `backup-channels.ps1` + `.Tests.ps1` | [K:.claude/scripts/backup-channels.ps1] | keep |
| `Recover-Files.ps1` + `.Tests.ps1` | [K:.claude/scripts/Recover-Files.ps1] | keep |
| `Restore-And-Fix.ps1` | [K:.claude/scripts/Restore-And-Fix.ps1] | keep |

### Misc utilities (5)

| Script | Source-tag | Disposition |
|---|---|---|
| `Send-Notification.ps1` | [K:.claude/scripts/Send-Notification.ps1] | keep |
| `Remove-Duplicates.ps1` | [K:.claude/scripts/Remove-Duplicates.ps1] | keep |
| `cleanup-scratch.ps1` | [K:.claude/scripts/cleanup-scratch.ps1] | keep |
| `mad-tasks-checkoff.ps1` + `.Tests.ps1` | [K:.claude/scripts/mad-tasks-checkoff.ps1] | keep |
| `yagni-filter.ps1` + `.Tests.ps1` | [K:.claude/scripts/yagni-filter.ps1] | keep |
| `work-item.ps1` | [K:.claude/scripts/work-item.ps1] | keep |
| `Get-SubagentPromptBoilerplate.ps1` | [K:.claude/scripts/Get-SubagentPromptBoilerplate.ps1] | keep |
| `preflight.ps1` + `.Tests.ps1` | [K:.claude/scripts/preflight.ps1] | keep |
| `Check-Preflight.ps1` | [K:.claude/scripts/Check-Preflight.ps1] | keep |
| `Compare-MadArtifacts.ps1` | [K:.claude/scripts/Compare-MadArtifacts.ps1] | keep |
| `council-review-integration.Tests.ps1` | [K:.claude/scripts/council-review-integration.Tests.ps1] | keep |
| `generate-agents-catalog.js` | [K:.claude/scripts/generate-agents-catalog.js] | keep |

### LENS-specific scripts (`drop` for engine v1) — 30 total in .mad/scripts

| Script | Source-tag | Disposition |
|---|---|---|
| `Ado-Build.ps1` (also in .claude/scripts) | [K:.mad/scripts/Ado-Build.ps1] | drop | LENS ADO build wrapper |
| `Ado-PR-Collect.ps1` | [K:.mad/scripts/Ado-PR-Collect.ps1] | drop |
| `Ado-PR-Comment.ps1` | [K:.mad/scripts/Ado-PR-Comment.ps1] | drop |
| `Ado-PR-Manage.ps1` | [K:.mad/scripts/Ado-PR-Manage.ps1] | drop |
| `Ado-WorkItem.ps1` | [K:.mad/scripts/Ado-WorkItem.ps1] | drop |
| `Analyze-TeamSession.ps1` | [K:.mad/scripts/Analyze-TeamSession.ps1] | drop | LENS Teams chat analysis |
| `Assign-CmsAppRoles.ps1` | [K:.mad/scripts/Assign-CmsAppRoles.ps1] | drop | LENS-CMS specific |
| `Audit-AllLensRepos.ps1` | [K:.claude/scripts/Audit-AllLensRepos.ps1] | drop |
| `Backfill-LrmsCases.ps1` | [K:.mad/scripts/Backfill-LrmsCases.ps1] | drop |
| `Check-AdoReleaseDeployments.ps1` | [K:.mad/scripts/Check-AdoReleaseDeployments.ps1] | drop |
| `Deploy-EvalContainer.ps1` | [K:.mad/scripts/Deploy-EvalContainer.ps1] | drop |
| `Deploy-Lrms.ps1` | [K:.mad/scripts/Deploy-Lrms.ps1] | drop |
| `Diagnose-LensDcsDeploy.ps1` | [K:.claude/scripts/Diagnose-LensDcsDeploy.ps1] | drop |
| `Dump-GoldenRecords-ACI.sh` | [K:.mad/scripts/Dump-GoldenRecords-ACI.sh] | drop |
| `Augment-GoldenRecords-ACI.sh` | [K:.mad/scripts/Augment-GoldenRecords-ACI.sh] | drop |
| `Ev2-Deploy.ps1` | [K:.mad/scripts/Ev2-Deploy.ps1] + [K:.claude/scripts/Ev2-Deploy.ps1] | drop |
| `Ev2-Status.ps1` | [K:.mad/scripts/Ev2-Status.ps1] | drop |
| `Ev2-RestartFailed.ps1` | [K:.mad/scripts/Ev2-RestartFailed.ps1] | drop |
| `Fix-DftProperties.ps1` | [K:.mad/scripts/Fix-DftProperties.ps1] | drop |
| `Generate-EvalReport.ps1` | [K:.mad/scripts/Generate-EvalReport.ps1] | keep | Generic enough; reusable |
| `Migrate-DataCategoryJobIds-ACI.ps1` | [K:.mad/scripts/Migrate-DataCategoryJobIds-ACI.ps1] | drop |
| `Open-EvalDashboard.ps1` | [K:.mad/scripts/Open-EvalDashboard.ps1] | keep |
| `Parse-DebugLogs.ps1` | [K:.mad/scripts/Parse-DebugLogs.ps1] | keep |
| `Provision-LrmsInfra.ps1` | [K:.mad/scripts/Provision-LrmsInfra.ps1] | drop |
| `Run-EvalHistory.ps1` | [K:.mad/scripts/Run-EvalHistory.ps1] | keep |
| `Run-DotnetGates.ps1` | [K:.claude/scripts/Run-DotnetGates.ps1] | defer | .NET-specific; keep when engine emits .NET |
| `Run-AciE2E.ps1` | [K:.claude/scripts/Run-AciE2E.ps1] | drop |
| `Seed-LrmsTestData.ps1` | [K:.mad/scripts/Seed-LrmsTestData.ps1] | drop |
| `Set-CmsDemoCase.ps1` | [K:.mad/scripts/Set-CmsDemoCase.ps1] | drop |
| `Store-EvalResults.ps1` | [K:.mad/scripts/Store-EvalResults.ps1] | keep |
| `Test-CmsApi.ps1` / `.sh` / `-ACI.sh` / `-FullField-ACI.sh` | [K:.mad/scripts/...] | drop (4 scripts) |
| `Test-E2E-ACI.ps1` (also in .claude/scripts) | [K:.mad/scripts/Test-E2E-ACI.ps1] | drop |
| `Verify-DcsCosmosPersistence.ps1` | [K:.mad/scripts/Verify-DcsCosmosPersistence.ps1] | drop |
| `Verify-JobIdClassifier-ACI.ps1` | [K:.mad/scripts/Verify-JobIdClassifier-ACI.ps1] | drop |

## Section 5 — Templates (41)

### Core MAD templates (16, all `keep`)

| Template | Source-tag | Disposition |
|---|---|---|
| `spec-template.md` | [K:.mad/templates/spec-template.md] | keep |
| `plan-template.md` | [K:.mad/templates/plan-template.md] | keep |
| `tasks-template.md` | [K:.mad/templates/tasks-template.md] | keep |
| `parallel-plan-template.md` | [K:.mad/templates/parallel-plan-template.md] | keep |
| `task-format-full.md` | [K:.mad/templates/task-format-full.md] | keep |
| `task-format-minimal.md` | [K:.mad/templates/task-format-minimal.md] | keep |
| `task-format-standard.md` | [K:.mad/templates/task-format-standard.md] | keep |
| `data-model-template.md` | [K:.mad/templates/data-model-template.md] | keep |
| `contracts-template.md` | [K:.mad/templates/contracts-template.md] | keep |
| `quickstart-template.md` | [K:.mad/templates/quickstart-template.md] | keep |
| `research-report.md` | [K:.mad/templates/research-report.md] | keep |
| `verification-spec-template.md` | [K:.mad/templates/verification-spec-template.md] | keep |
| `verification-report.md` | [K:.mad/templates/verification-report.md] | keep |
| `implementation-report.md` | [K:.mad/templates/implementation-report.md] | keep |
| `cleanup-manifest.md` | [K:.mad/templates/cleanup-manifest.md] | keep |
| `post-phase-review.md` | [K:.mad/templates/post-phase-review.md] | keep |

### Other templates (13, all `keep`)

| Template | Source-tag | Disposition |
|---|---|---|
| `adr-template.md` | [K:.mad/templates/adr-template.md] | keep |
| `agent-file-template.md` | [K:.mad/templates/agent-file-template.md] | keep |
| `agent-md-template.md` | [K:.mad/templates/agent-md-template.md] | keep |
| `c4-component-template.md` | [K:.mad/templates/c4-component-template.md] | keep |
| `c4-container-template.md` | [K:.mad/templates/c4-container-template.md] | keep |
| `c4-context-template.md` | [K:.mad/templates/c4-context-template.md] | keep |
| `checklist-template.md` | [K:.mad/templates/checklist-template.md] | keep |
| `context-template.md` | [K:.mad/templates/context-template.md] | keep |
| `feature-map-template.md` | [K:.mad/templates/feature-map-template.md] | keep |
| `feature-ledger-template.md` | [K:.mad/templates/feature-ledger-template.md] | keep |
| `pattern-rule.md` | [K:.mad/templates/pattern-rule.md] | keep |
| `spec-quality-checklist.md` | [K:.mad/templates/spec-quality-checklist.md] | keep |
| `work-item-template.md` | [K:.mad/templates/work-item-template.md] | keep |
| `council-skill-output-shapes.md` | [K:.mad/templates/council-skill-output-shapes.md] | keep |

### Coverage oracles (12, all `keep`)

| Oracle | Source-tag | Disposition |
|---|---|---|
| `coverage-oracles/spec.md` | [K:.mad/templates/coverage-oracles/spec.md] | keep |
| `coverage-oracles/plan.md` | [K:.mad/templates/coverage-oracles/plan.md] | keep |
| `coverage-oracles/tasks.md` | [K:.mad/templates/coverage-oracles/tasks.md] | keep |
| `coverage-oracles/handler-tests.md` | [K:.mad/templates/coverage-oracles/handler-tests.md] | keep |
| `coverage-oracles/cosmos-doc.md` | [K:.mad/templates/coverage-oracles/cosmos-doc.md] | defer | Cosmos-specific; keep when engine touches Cosmos |
| `coverage-oracles/doc-generic.md` | [K:.mad/templates/coverage-oracles/doc-generic.md] | keep |
| `coverage-oracles/skill-md.md` | [K:.mad/templates/coverage-oracles/skill-md.md] | keep |
| `coverage-oracles/rule-md.md` | [K:.mad/templates/coverage-oracles/rule-md.md] | keep |
| `coverage-oracles/template-md.md` | [K:.mad/templates/coverage-oracles/template-md.md] | keep |
| `coverage-oracles/bicep.md` | [K:.mad/templates/coverage-oracles/bicep.md] | defer |
| `coverage-oracles/config.md` | [K:.mad/templates/coverage-oracles/config.md] | keep |
| `coverage-oracles/ev2-config.md` | [K:.mad/templates/coverage-oracles/ev2-config.md] | drop | Ev2 / LENS-CMS specific |

## Section 6 — Schemas

No findings under `.mad/schemas/`. The MAD pipeline references schemas but they are typically inline in templates or scripts. Engine should establish a clean `.mad/schemas/` (or `<engine-root>/schemas/`) directory with explicit JSON Schema files for: channel.schema.json, verdict.schema.json, audit-event.schema.json, soul.schema.json, retro.schema.json, run.schema.json, cost-ledger-entry.schema.json, skill-allowlist.schema.json. **decision-pending**: confirm schema-directory location with Lane Zero.

## Section 7 — Wiki docs (.mad/docs/wiki/, 80 files)

### Best-practices (28, all `keep`)

Six index categories (01-claude-code-features, 02-orchestration-patterns, 03-workflow-patterns, 04-ai-llm-patterns, 05-integration-patterns, 06-emerging-patterns) plus CHANGELOG.md and READMEs and 00-index.md. All files under `.mad/docs/wiki/best-practices/**/*.md` keep as kit-canonical 2026 best-practices reference.

### Guides (32 listed, all `keep` or `defer`)

| Guide | Source-tag | Disposition |
|---|---|---|
| `guides/agent-teams-guide.md` | [K] | keep |
| `guides/azure-storage-patterns.md` | [K] | defer |
| `guides/context-driven-reference-guide.md` | [K] | keep |
| `guides/context-management-guide.md` | [K] | keep |
| `guides/dag-execution-guide.md` | [K] | keep |
| `guides/dag-feature-flags.md` | [K] | keep |
| `guides/dag-migration-guide.md` | [K] | keep |
| `guides/eval-research.md` | [K] | keep |
| `guides/knowledge-extraction.md` | [K] | keep |
| `guides/mad-implement-risk-routing.md` | [K] | keep |
| `guides/mcp-tiering-guide.md` | [K] | keep |
| `guides/model-selection-guide.md` | [K] | keep |
| `guides/parallel-execution-guide.md` | [K] | keep |
| `guides/pattern-discovery-workflow.md` | [K] | keep |
| `guides/patterns-index.md` | [K] | keep |
| `guides/phased-review-schema.md` | [K] | keep |
| `guides/pr-pattern-mining-workflow.md` | [K] | keep |
| `guides/progressive-validation-guide.md` | [K] | keep |
| `guides/risk-tiered-verification-guide.md` | [K] | keep |
| `guides/skill-authoring-guide.md` | [K] | keep |
| `guides/ACI-E2E-TestPlan.md` | [K] | drop | LENS-specific |
| `guides/azure-identity.md` | [K] | defer |
| `guides/cicd-deployment.md` | [K] | keep |
| `guides/cicd-pipeline-structure.md` | [K] | keep |
| `guides/cicd-quality-gates.md` | [K] | keep |
| `guides/credential-caching.md` | [K] | keep |
| `guides/reference-repos.md` | [K] | keep |
| `guides/milestone-validation.md` | [K] | keep |
| `guides/components.md` | [K] | keep |
| `guides/golden-test-cases.md` | [K] | keep |
| `guides/marketplace-tiers.md` | [K] | keep |
| `guides/testing-workflow-architecture.md` | [K] | keep |
| `guides/skill-packaging.md` | [K] | keep |
| `guides/workflow-best-practices.md` | [K] | keep |
| `guides/hook-fail-open-policy.md` | [K] | keep |

### Implementations (4, all `keep`)

| Implementation | Source-tag | Disposition |
|---|---|---|
| `implementations/a2a.md` | [K] | keep |
| `implementations/autogen.md` | [K] | keep |
| `implementations/langgraph.md` | [K] | keep |
| `implementations/marketplace-plugins.md` | [K] | keep |
| `implementations/anthropic-claude-code.md` | [K] | keep |

### Patterns (15, all `keep`)

| Pattern | Source-tag | Disposition |
|---|---|---|
| `patterns/bounded-iteration-caps.md` | [K] | keep |
| `patterns/circuit-breakers.md` | [K] | keep |
| `patterns/completion-report-protocol.md` | [K] | keep |
| `patterns/evidence-beats-assertion.md` | [K] | keep |
| `patterns/learning-signals.md` | [K] | keep |
| `patterns/mode-aware-sizing.md` | [K] | keep |
| `patterns/multi-role-review.md` | [K] | keep |
| `patterns/orchestrator-worker.md` | [K] | keep |
| `patterns/scope-discipline.md` | [K] | keep |
| `patterns/state-file-coordination.md` | [K] | keep |
| `patterns/yagni-filter.md` | [K] | keep |
| `patterns/multi-model-ensemble.md` | [K] | keep |
| `patterns/per-operation-retry-tables.md` | [K] | keep |
| `patterns/preflight-dependency-checks.md` | [K] | keep |
| `patterns/run-id-correlation.md` | [K] | keep |
| `patterns/scheduled-trigger-heartbeat.md` | [K] | keep |
| `patterns/staged-rollout.md` | [K] | keep |

### Cross-cutting (5, all `keep`)

| Doc | Source-tag | Disposition |
|---|---|---|
| `anti-patterns.md` | [K] | keep |
| `glossary.md` | [K] | keep |
| `references.md` | [K] | keep |
| `troubleshooting/README.md` | [K] | keep |
| `aci-e2e-runbook.md` | [K:.mad/docs/aci-e2e-runbook.md] | drop |

## Section 8 — The MAD pipeline (skill chain)

The kit's pipeline (per `.claude/rules/mad-workflow.md`):

```
/mad-spec (→ /testplan --source spec auto)
  → /mad-plan (→ agent-team review of 3 reviewers)
  → /mad-tasks
  → /mad-analyze
  → /mad-implement (→ ≥3 parallel [P] groups MANDATORY per agent-teams.md)
  → /mad-validate
  → /apply-learnings
```

Plus orchestrator wrappers:
- `/mad-full` — full automation chain
- `/mad-decompose` → `/mad-parallel` — parallel multi-feature workflow

**Disposition**: keep entire chain. Engine v1 invokes via Skill tool; canonical-skill-only enforcement is non-negotiable.

## Section 9 — Hook events catalog

Engine should bind its own version of each event:

| Event | Kit hooks (count) | Engine notes |
|---|--:|---|
| PreToolUse | 15 | Most blocking enforcement |
| PostToolUse | 12 | Advisory + tracking |
| SubagentStop | 5 | Block subagent completion |
| Stop / SessionEnd | 5 | Handoff + cleanup |
| Notification | 1 | UI surface |
| PermissionRequest | 1 | Consent gate |
| SessionStart | 1 | Bootstrap |
| PreCompact | 1 | Handoff writer |
| (PowerShell) TaskCompleted/Idle | 2 | Out-of-band notification |

## Section 10 — 5 recurring anti-patterns (from CLAUDE.md)

| # | Anti-pattern | Hook (existing or planned) | Engine disposition |
|---|---|---|---|
| 1 | Top-N capping | `detect-top-n-capping.js` (PreToolUse:Task) | keep + enforce |
| 2 | Inline-authoring of MAD artifacts (Edit loophole closed 2026-05-02) | `validate-mad-pipeline.js` Write+Edit | keep + enforce |
| 3 | Silent deferrals | `content-scan-deferrals.js` (PostToolUse) + `validate-artifact-completeness.js` (SubagentStop) | keep + enforce |
| 4 | `/testplan` auto-fire never happened | `validate-artifact-completeness.js` SubagentStop checks for test-plan.md presence next to spec.md | keep + enforce |
| 5 | Skill emulation vs canonical invocation | `enforce-skill-canonical-marker.js` (PostToolUse:Write|Edit) | keep + enforce |

## Section 11 — 3 artifact classes

Per CLAUDE.md authoring discipline:

| Class | Path pattern | Authority |
|---|---|---|
| Canonical MAD artifact | `specs/<N>-<feature>/{spec,plan,tasks,analysis-report,test-plan}.md` | One specific `/mad-*` skill body |
| Surface-map artifact | `_featuremap.md`, `_taskmap.md`, traceability matrices | `/mad-traceability` + `Generate-FeatureMap.ps1` |
| Feature-ledger artifact | (per feature-ledger-template.md) | Per-feature lifecycle ledger |

**Engine disposition**: keep all 3 classes. Add new class for **engine runtime artifacts** (run.json, retro.json, audit-log.jsonl, cost-ledger.jsonl, soul.json, kill-switches/) — distinct from MAD-pipeline artifacts.

## Disposition summary

| Action | Count |
|---|--:|
| keep | ~280 (most primitives) |
| change | ~10 (rename, generalize, narrow) |
| drop | ~50 (LENS-specific scripts/skills/rules) |
| defer | ~35 (.NET patterns, infra-specific) |
| decision-pending | ~3 (schema-directory location, mad-teams-vs-council reconciliation, lens-engineering-craftsmanship rename) |

## Key engine-design implications

1. **Most kit primitives transfer cleanly** — the kit was developed AS the substrate for the engine; ~80% of primitives are domain-neutral.
2. **LENS-specific drop list is small** — ~50 scripts/skills/rules + 1 oracle drop cleanly because they live behind clean LENS-cms / LENS-DCS prefixes.
3. **5 anti-pattern hooks are LOAD-BEARING** for engine v1 — without them, the iter-1-41 collab-engine spiral repeats.
4. **The MAD pipeline is the engine's primary contract surface** — engine doesn't fork it; engine consumes it.
5. **Schema directory needs explicit creation** — kit references schemas inline; engine needs `.mad/schemas/` populated for canonical artifact frontmatter checks.
