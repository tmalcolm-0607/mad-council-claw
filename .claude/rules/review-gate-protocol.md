# Review Gate Protocol

Canonical reference for automatic review gates embedded in the MAD pipeline. All skills reference this rule instead of duplicating logic.

---

## Core Pattern

```
Phase output produced
  → Check config (AUTO_REVIEW_ENABLED + phase flag)
  → Spawn 2-3 domain-reviewer agents (parallel Task calls)
  → Collect findings by severity
  → Persist to {FEATURE_DIR}/reviews/{phase}-review.md
  → BLOCK on CRITICAL / WARN on MAJOR / LOG on MINOR
  → Auto-debate if ≥ AUTO_DEBATE_THRESHOLD CRITICAL findings
```

---

## Configuration

All flags live in `.claude/settings.local.json` under `env`. All default to `true` unless noted.

| Flag | Default | Description |
|------|---------|-------------|
| `AUTO_REVIEW_ENABLED` | `true` | Master switch — disables all review gates when `false` |
| `AUTO_REVIEW_SPEC` | `true` | Review gate after spec generation |
| `AUTO_REVIEW_PLAN` | `true` | Review gate after plan generation |
| `AUTO_REVIEW_TASKS` | `true` | Review gate after task generation |
| `AUTO_REVIEW_IMPLEMENT` | `true` | Code review at implementation checkpoints |
| `AUTO_REVIEW_DECOMPOSE` | `true` | Review gate after decomposition |
| `AUTO_REVIEW_IMPLEMENT_FREQUENCY` | `major` | `every` = every checkpoint, `major` = phase boundaries, `final` = end only |
| `AUTO_DEBATE_THRESHOLD` | `2` | Min CRITICAL findings to trigger auto-debate |
| `REVIEW_AGENT_MODEL` | `sonnet` | Model for reviewer agents (`sonnet` or `opus`) |

### Escape Hatches

- **Per-invocation**: Pass `--skip-review` flag to any skill
- **Per-phase**: Set individual phase flag to `false`
- **Global**: Set `AUTO_REVIEW_ENABLED=false`

---

## Config Check Logic

Every skill with a review gate follows this check sequence:

```
1. If --skip-review passed → SKIP (log: "Review skipped by user flag")
2. Read settings.local.json → check AUTO_REVIEW_ENABLED
   - If false or "false" or "0" → SKIP (log: "Reviews disabled globally")
3. Check phase-specific flag (e.g., AUTO_REVIEW_PLAN)
   - If false or "false" or "0" → SKIP (log: "Plan review disabled")
4. Proceed with review gate
```

---

## Reviewer Dispatch

### With Agent Teams Enabled

Spawn reviewers as teammates (parallel, isolated contexts):
- Read `agent-teams-config.json` for phase entry
- If phase entry exists and `enabled=true` → team dispatch
- Each reviewer is a `domain-reviewer` agent with a specific domain

### Without Agent Teams (Subagent Fallback)

Spawn reviewers as parallel Task calls in a single message:
- Each reviewer is a `domain-reviewer` agent (subagent_type: `domain-reviewer`)
- Model set by `REVIEW_AGENT_MODEL` flag
- All calls made in the same message block for true parallelism

---

## Review Domains by Phase

| Phase | Reviewer 1 | Reviewer 2 | Reviewer 3 |
|-------|-----------|-----------|-----------|
| **spec** (contract) | security | architecture | completeness |
| **spec** (vision/idea) | scope | completeness | feasibility |
| **plan** | architecture | feasibility | pattern-compliance |
| **tasks** | completeness | dependency-correctness | — |
| **implement** | code-quality | security | — |
| **decompose** | vertical-slice | dependency | scope |

**Vision vs Contract**: Specs under `specs/ideas/` get scope/completeness/feasibility review. Specs under `specs/<N>-<feature>/` get security/architecture/completeness review.

---

## Severity Classification

| Severity | Meaning | Gate Behavior |
|----------|---------|---------------|
| **CRITICAL** | Blocks correctness, security vulnerability, or architectural flaw | **BLOCK** — must be resolved before proceeding |
| **MAJOR** | Significant gap, missing requirement, or poor pattern | **WARN** — user notified, may proceed with acknowledgment |
| **MINOR** | Style, naming, minor improvements | **LOG** — recorded in review artifact, no interruption |

---

## Auto-Debate Trigger

When a review gate produces ≥ `AUTO_DEBATE_THRESHOLD` CRITICAL findings:

1. Spawn a 1-round devils-advocate debate (use `/debate` skill internally)
2. Format: devils-advocate, 1 round
3. Topic: the proposed fixes for the CRITICAL findings
4. Persist debate output to `{FEATURE_DIR}/reviews/{phase}-debate.md`
5. Present synthesized recommendation to user

---

## Artifact Persistence

Every review gate writes its output to:

```
{FEATURE_DIR}/reviews/{phase}-review.md
```

Where:
- `{FEATURE_DIR}` = the spec directory (e.g., `specs/3-my-feature/`)
- `{phase}` = `spec`, `plan`, `tasks`, `implement-{checkpoint}`, `decompose`

### Review Artifact Format

```markdown
# {Phase} Review — {Feature Name}

**Date**: {ISO timestamp}
**Reviewers**: {domain1}, {domain2}, {domain3}
**Model**: {model used}

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | N |
| MAJOR | N |
| MINOR | N |

## CRITICAL Findings

### C1: {title}
- **Domain**: {reviewer domain}
- **Location**: {file:line or section reference}
- **Issue**: {description}
- **Recommendation**: {proposed fix}

## MAJOR Findings

### M1: {title}
...

## MINOR Findings

### m1: {title}
...

## Gate Decision

{BLOCKED | PASSED_WITH_WARNINGS | PASSED}
```

---

## Integration with Existing Gates

Review gates complement (do not replace) existing quality gates:

| Existing Gate | Review Gate Addition |
|---------------|---------------------|
| Build/Test/Coverage (mechanical) | Code quality + security review (semantic) |
| Implementability gates (mad-spec 7.1) | Architecture + completeness review |
| Consistency check (mad-analyze) | Dependency correctness + completeness review |

---

## Anti-Patterns

| Anti-Pattern | Correct |
|--------------|---------|
| Review findings only in conversation text | Persist to `{FEATURE_DIR}/reviews/` |
| Running all reviewers as Opus | Use Sonnet (default) — 40% cheaper, sufficient for review |
| Blocking on every MAJOR finding | Only CRITICAL blocks; MAJOR warns |
| Skipping review because "it's just a small change" | Review gates are cheap (~25-45K tokens); skip only via explicit flag |
| Manual reviewer orchestration after every phase | Let the skill handle it automatically |
| Duplicating review logic across skills | Reference this rule file |
