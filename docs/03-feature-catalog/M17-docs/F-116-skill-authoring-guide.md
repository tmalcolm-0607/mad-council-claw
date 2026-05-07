---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-116
short-slug: skill-authoring-guide
milestone: M17
provenance:
  surfaces:
    - cp:docs/skills
    - kit:rules/skill-standards.md
    - kit:rules/canonical-skill-only.md
    - kit:rules/canonical-artifact-frontmatter.md
    - foundational-plan.md M17 docs section
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
  LOCKED if GREEN AND reviews/F-116-skill-authoring-guide-review.md exists with verdict: ACCEPT.
depends-on: [F-040, F-115]
out-of-scope-notes: |
  Sandbox skill testing harness is OUT for v1 (the guide describes the
  contract; users run skills against their own engine for validation).
  Marketplace / skill-publishing pipeline is OUT (M11+ scope). Skill-versioning
  semver enforcement is OUT for v1; v1 covers semver convention in docs only.
  Skill-translation (i18n of SKILL.md bodies) is v1.5. Auto-generated SKILL.md
  scaffolding tool is v1.5; v1 = hand-authored from the template in this guide.
confidence: high
---

# F-116 — Skill authoring guide

## Behavior contract

The repo MUST ship `docs/skill-authoring-guide.md` covering: (1) what a skill IS (frontmatter + body + optional templates/evals/scripts), (2) the canonical SKILL.md template with required keys (`name`, `description`, `allowed-tools`, `disable-model-invocation`, `version`, `inherits-rules`) per `rules/skill-standards.md`, (3) the 6-dimension compliance scoring (frontmatter integrity / Best Practices section / Standards section / evals / templates / multi-pass + cross-model) and how to hit Tier S, (4) how to declare canonical-skill-only contracts when authoring a skill that emits MAD artifacts (per `rules/canonical-skill-only.md` and `rules/canonical-artifact-frontmatter.md`), (5) how to author the corresponding `templates/` and `evals/` subdirectories, (6) how to inherit kit rules vs. write skill-specific rules, (7) common anti-patterns (wildcard `allowed-tools`, missing `disable-model-invocation`, emulating canonical skills inline), (8) a worked end-to-end example (a hypothetical `/example-greeter` skill from frontmatter to evals). Every assertion in the guide cites the corresponding kit rule (FETCH BEFORE CITE per `rules/verification-protocol.md`).

## Acceptance scenarios

1. **Given** an engineer who has never authored a skill, **When** they read `docs/skill-authoring-guide.md` end-to-end, **Then** they can produce a Tier-A or higher skill (≥5/6 dimensions) on the first attempt, validated by `/skill-audit` outputting Tier A or S in `.mad/scratch/skill-audit-matrix.csv`.
2. **Given** a CI link-check across `docs/skill-authoring-guide.md`, **When** the job runs, **Then** every cited kit rule path resolves, every code-block example parses as valid YAML/Markdown, and the worked-example skill fixture passes `/skill-audit` at Tier S.
3. **Given** the guide describes the canonical-skill-only contract, **When** an engineer follows the section "authoring a skill that emits MAD artifacts", **Then** the example shows the explicit Skill-tool invocation pattern, the frontmatter signature contract, and the failure mode if the contract is bypassed (links to `rules/canonical-skill-only.md`) — the contract is not silently softened.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/e2e/docs/skill-authoring-tier-a-first-attempt.test.ts` | e2e | RED | scenario 1 |
| (TBD) `tests/integration/docs/skill-guide-link-and-fixture-audit.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/docs/skill-guide-canonical-contract-citation.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-040 (skills runtime; the guide describes the runtime contract), F-115 (architecture docs cross-link skills boundaries)
- **Soft:** Every kit rule referenced (skill-standards / canonical-skill-only / canonical-artifact-frontmatter / verification-protocol)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:docs/skills | clawpilot skill docs as a starting reference for the engine's authoring guide |
| kit:rules/skill-standards.md | 6-dimension compliance contract is the centerpiece of the guide |
| kit:rules/canonical-skill-only.md | guide explicitly calls out the canonical-only contract for MAD-artifact-emitting skills |
| kit:rules/canonical-artifact-frontmatter.md | frontmatter signature contract for skill outputs |
| foundational-plan.md M17 | docs scope: skill authoring is one of the 5 M17 docs deliverables |

## Implementation notes

(empty — populated when implementation begins)
