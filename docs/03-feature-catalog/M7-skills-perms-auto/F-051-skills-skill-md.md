---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-051
short-slug: skills-skill-md
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/skills.ts
    - cp:common/skill-sanitization.ts
    - cp:electron/yaml-utils.ts
    - kit:docs/04-research/frontier-2026/anthropic-skills-authoring.md
    - kit:rules/skill-standards.md
    - kit:rules/canonical-skill-only.md
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-051-skills-skill-md-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008]
out-of-scope-notes: |
  Bundled-skills installation flow is F-052.
  Per-session toggle is F-053.
  Custom-loading from arbitrary directories is F-054.
  Allowlist enforcement is F-055.
  Version pinning by sha256 is F-056.
  Pin-expiry is F-057.
  3-tier permission classification of skills is F-058 (M7 perms group).
  Skill marketplace UI is M18 (F-119..F-121).
  Pair-programming-mode (Claude-A-with-Claude-B) is a NEW F-NNN candidate from Anthropic Skills authoring research; deferred to M19 catalog drop.
confidence: high
---

# F-051 — Skills SKILL.md format

## Behavior contract

A skill is a directory containing a `SKILL.md` file with required YAML frontmatter (`name`, `description`, optional `allowed-tools`, `disable-model-invocation`, `version`, `inherits-rules`, `references`). The `name` field MUST be ≤64 chars, kebab-case, no `anthropic` or `claude` substrings; the `description` MUST be ≤1024 chars, third-person, and include both WHAT the skill does and WHEN to invoke it. The engine loads SKILL.md via the YAML loader (`yaml-utils.ts`-style), validates frontmatter via Zod, sanitizes content (`skill-sanitization.ts`-style: no remote-fetch directives, no `eval`-class instructions, no nested `>1`-level reference paths), and registers the skill in the in-memory skill registry indexed by `name`. The body MUST be under 500 lines; the loader emits a warning above that threshold.

## Acceptance scenarios

1. **Given** a skill directory `skills/processing-pdfs/SKILL.md` with valid frontmatter (name=`processing-pdfs`, description=140 chars third-person), **When** the engine starts, **Then** the registry contains an entry `{name: "processing-pdfs", source: "skills/processing-pdfs/SKILL.md", validated: true}` and no validation errors are logged.
2. **Given** a skill with `name: "claude-helper"` (contains forbidden substring), **When** the engine attempts registration, **Then** registration fails with `SKILL_NAME_FORBIDDEN_SUBSTRING` and the skill is excluded from the registry.
3. **Given** a SKILL.md with 723-line body, **When** the engine loads it, **Then** registration succeeds AND a warning is logged with shape `{ skill: "X", body_lines: 723, threshold: 500, recommendation: "split via progressive disclosure" }`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/skills/skill-md-frontmatter-validation.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/skills/skill-md-name-forbidden-substring.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/skills/skill-md-body-length-warning.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel hosts the registry), F-008 (storage layout defines `<state-dir>/skills/` location)
- **Soft:** F-052 (bundled installation produces SKILL.md files this loader consumes), F-058 (3-tier perms classify the skill at registration time)
- **Independent:** all other M7 features

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "SKILL.md" is item 1 of the M7 catalog list |
| cp:electron/skills.ts | 766-LOC reference implementation of skill loader |
| cp:common/skill-sanitization.ts | sanitization with Zod validation pattern |
| cp:electron/yaml-utils.ts | YAML frontmatter parsing utility |
| kit:docs/04-research/frontier-2026/anthropic-skills-authoring.md | Frontmatter contract: name ≤64 chars, description ≤1024 chars third-person |
| kit:rules/skill-standards.md | Dimension 1 (frontmatter integrity) — kit's own discipline |

## Implementation notes

(empty — populated when implementation begins)
