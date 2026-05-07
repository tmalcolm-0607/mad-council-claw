# Skill Standards

Every skill under `.claude/skills/` SHOULD comply with these standards. Compliance is checked by `/skill-audit` and surfaced in `.mad/scratch/skill-audit-matrix.csv`.

The 6 dimensions a fully-compliant skill carries:

1. **Frontmatter integrity** — valid YAML, required keys present, no LENS-CMS-specific names in placeholder positions
2. **Best Practices section** — explicit `## Best Practices` heading documenting the do's
3. **Standards section** — explicit `## Standards` (or `## Conventions`) heading citing inherited rules and naming conventions
4. **Evals** — `evals/` subdirectory with synthetic fixtures and expected outputs
5. **Templates** — `templates/` subdirectory (when the skill emits structured artifacts) OR explicit reference to `.mad/templates/<shape>` shared templates
6. **Multi-pass + cross-model options** — at least one of: `--council` mode (3-role adversarial), `--deep` mode (cross-repo phased), `--quick` mode (blocking-only), Copilot CLI dispatch (cross-model verification)

A skill that touches code or produces consequential artifacts SHOULD have all 6. A pure utility (e.g. `git-commit`) only needs 1, 2, 3.

---

## Dimension 1 — Frontmatter integrity

```yaml
---
name: <skill-name>                    # required, kebab-case, matches dir name
description: <one-line summary>       # required, ≤200 chars
allowed-tools:                        # required, list (or comma string)
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Task
disable-model-invocation: true|false  # required after allowed-tools list
version: 1.0.0                        # recommended, semver
inherits-rules:                       # optional, but encouraged for consequential skills
  - rules/verification-protocol.md
  - rules/prompt-injection-policy.md
references:                           # optional, link to evals/templates/related skills
  - .claude/rules/skill-standards.md
  - evals/<fixture>.md
---
```

Anti-patterns that FAIL audit:
- `disable-model-invocation: true` placed BEFORE the list items of `allowed-tools` (breaks YAML parsing). Caught in May 2026 cleanup on `pattern-generate` and `registry-install`.
- `allowed-tools:` empty (null) when the body uses Read/Write/Bash.
- Description exceeds 200 chars or includes implementation detail that belongs in the body.

## Dimension 2 — Best Practices section

Every consequential skill carries a `## Best Practices` section enumerating the do's, pulling from this kit's load-bearing rules:

```markdown
## Best Practices

- **FETCH BEFORE CITE** — read source files before claiming behavior; never reference a function or contract without opening it (per `rules/verification-protocol.md`).
- **Anti-hallucination** — when a category produces no findings, state that explicitly. Don't pad to fill the category.
- **Output Contract** — every emitted finding/artifact carries: severity tag (BLOCKING / MUST-FIX / SHOULD-FIX / CONSIDER / PRAISE) + file:line + evidence snippet (≤6 lines) + cited rule + suggested fix.
- **Confidence floor** — emit only findings at confidence ≥ severity-floor (BLOCKING ≥80, MUST-FIX ≥70, SHOULD-FIX ≥60, CONSIDER ≥50, PRAISE ≥70).
- **Existing-thread dedup** — when consuming prior threads/comments, suppress findings within ±5 lines of resolved threads.
- **WorkIQ context** — auto-trigger when the artifact references a work item, feature area, or known author; graceful-degrade if the MCP is unavailable.
- **Auto-fan-out** — when ≥3 confirm-asks accumulate at confidence 40-69, READ the referenced files in full and re-evaluate; don't ship a wall of mention-only findings.
```

Skill-specific best practices append after the kit-wide ones.

## Dimension 3 — Standards section

```markdown
## Standards

This skill inherits these load-bearing rules:
- `.claude/rules/non-negotiable-rules.md` — verb-bound permission fences
- `.claude/rules/verification-protocol.md` — FETCH BEFORE CITE / READ BEFORE EDIT / MATCH EXISTING STYLE / ACTUAL BEFORE PRESENT
- `.claude/rules/orchestration.md` — main coordinates, agents work
- `.claude/rules/quality-gates.md` — gate execution + output discipline (when applicable)
- `.claude/rules/skill-standards.md` — this document

Naming:
- Generic types use `Service*` placeholder (e.g. `ServiceValidationException`); consumer projects substitute their actual names (`CmsValidationException`, `LrmsValidationException`)
- Slash commands match skill directory names exactly: `/<skill-name>`
- Subcommand-bearing skills dispatch via first positional arg: `/<skill> <subcommand> [args]`
```

## Dimension 4 — Evals

Each skill carries `evals/` containing:
- `evals/README.md` — what the eval harness checks
- `evals/fixtures/<scenario>.md` — synthetic input artifact
- `evals/expected/<scenario>.md` — expected output for that input
- `evals/test.ps1` (or `test.js`) — runner that compares actual vs expected

The fixtures use **synthetic content** — no real engineer's voice, no real LENS-CMS code. The eval is purely structural: does the skill produce the right SHAPE of output for a given SHAPE of input?

Reference implementation: `.claude/skills/lens-engineering-craftsmanship/evals/`. The character-limits eval there is the canonical pattern to copy.

## Dimension 5 — Templates

For skills that emit structured artifacts (specs, plans, tasks, reports, comments), templates live in:
- `templates/` (per-skill, for skill-specific shapes), OR
- `.mad/templates/<shape>` (shared, for shapes used across multiple skills, e.g. idea.md, spec.md)

A template includes:
- Required-section headers
- Placeholder bracketed text: `[REPLACE: description of what goes here]`
- One worked example at the top labeled `> EXAMPLE — replace this when authoring`

The skill's body documents which template it uses and why.

## Dimension 6 — Multi-pass + cross-model

Consequential skills SHOULD support at least one multi-pass mode:

### `--council` mode (most rigorous)

Spawns the 3-role council (`advocate` / `skeptic` / `architect`) in parallel. Synthesizes a binding verdict (FIX / ACCEPT / ESCALATE / INVESTIGATE) using the same rubric as `/council-review` Step 8. Reference implementation: `.claude/skills/pr-review/SKILL.md` §`--council`.

### `--deep` mode (cross-repo)

Phased cross-repo review per `.claude/rules/phased-review-protocol.md`. Reference: `pr-review` and `council-review` both support this.

### `--quick` mode (blocking-only fast lane)

Skips WorkIQ + auto-mode-promotion; runs only Pass 1 security; confidence floor raised to ≥70 for all severities. Reference: `pr-review`.

### Copilot CLI dispatch (cross-model verification)

For skills where multi-model agreement is valuable (security review, contract migration, architectural decision), spawn parallel calls to Claude Opus AND GPT-5+ via Copilot CLI. Reference implementation: `lens-multi-model-review` plugin (Shayon Gupta, LENS-Common PR #5138039) — vendored as `.claude/rules/lens-multi-model-review-pattern.md` for reuse.

Pattern:
1. Detect Copilot CLI: `which copilot` / `which agency`
2. Save brief + diff to `$TEMP_DIR`
3. Spawn TWO `copilot --yolo -p ...` processes in parallel (one per model)
4. Wait for both, synthesize via cross-model agreement table
5. Block-on-CRITICAL — if either model flags a CRITICAL security pattern that isn't mitigated, vote `wait-for-author` / `reject`

If Copilot CLI is unavailable, fall back to spawning two parallel `Task` calls with role-distinguishing prompts on the same model (Opus role A vs Opus role B). Same orchestration shape; weaker disagreement signal.

---

## Compliance scoring

| Dimensions present | Tier |
|--------------------|------|
| 6/6 | **Tier S** — exemplar; cite as reference for other skills |
| 5/6 | **Tier A** — production-ready |
| 4/6 | **Tier B** — usable but flagged for refinement |
| 2-3/6 | **Tier C** — needs standardization pass |
| 0-1/6 | **Tier D** — broken; either fix or remove |

### Pure-utility exemption

Pure utility skills are exempt from one or more dimensions when the dimension does not apply to the skill's shape.

**Allowed exemption keys** (use these literal names in `tier-exempt:`):

| Key | Exempts | Use when |
|-----|---------|----------|
| `evals` | Dimension 4 (eval fixtures) | Skill has no input contract to fixture (pure-mechanical ops) |
| `templates` | Dimension 5 (templates) | Skill output is non-prescriptive (pure-mechanical or terminal) |
| `multi-pass` | Dimension 6 (Copilot CLI / cross-model) | Skill is a state mutation where cross-model adds no value (mechanical council ops, pure utilities) |
| `best-practices` | Dimension 2 (Best Practices section) | Skill embeds equivalent guidance via different structure (e.g. lens-engineering-craftsmanship) |
| `standards` | Dimension 3 (Standards section) | Same rationale as `best-practices` |

`tier-exempt: [frontmatter]` is **not allowed** — frontmatter integrity is mandatory for every skill.

**Examples:**

```yaml
# Pure mechanical commit ops
tier-exempt: [templates, multi-pass]

# Bespoke voice-toolkit shape
tier-exempt: [multi-pass, best-practices, standards]

# Mechanical state op (council-list)
tier-exempt: [multi-pass]
```

When the audit script reads `tier-exempt` it counts those dimensions as covered for tier scoring. A skill with 3 actual dimensions + 3 tier-exempt dimensions still scores 6/6 → Tier S.

Originally: `git-commit`, `memory`, `resume-handoff` were the canonical examples. The 2026-05 audit expanded the convention to also cover mechanical council-* skills (council-check, council-join, council-leave, council-list, council-open) and `lens-engineering-craftsmanship`.

## Continuous audit

Run `/skill-audit` to refresh `.mad/scratch/skill-audit-matrix.csv`. Skills below Tier B should appear in the next standardization batch.
