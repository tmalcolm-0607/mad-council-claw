---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-087
short-slug: high-blast-radius-skills-wired
milestone: M10
provenance:
  surfaces:
    - kit:lens-multi-model-review-pattern.md
    - kit:rules/skill-standards.md
    - kit:rules/prescriptive-content-review.md
    - ce:US-7
    - ce:FR-MULTI-001
    - cp:wave-002-wave-003-copilot-cli-design-review
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
  LOCKED if GREEN AND reviews/F-087-high-blast-radius-skills-wired-review.md exists with verdict: ACCEPT.
depends-on: [F-082, F-083, F-084, F-085, F-086]
out-of-scope-notes: |
  Auto-escalation to `--council` mode based on blast-radius axis ≥7 lives in
  `kit:rules/prescriptive-content-review.md` § Gap 5; this ledger covers the SKILL-side
  inheritance contract (frontmatter + body block), not the trigger logic.
  Specific skill-by-skill rollout sequencing is M19-deferred backlog (this ledger covers
  the contract; per-skill wiring is handled when each skill is authored / refreshed).
confidence: high
---

# F-087 — High-blast-radius skills wired for `--council` mode

## Behavior contract

Skills with `blast_radius ≥ 7` per `kit:rules/prescriptive-content-review.md` § Gap 5 (i.e., cross-team prescriptive material: kit rules, kit templates, doc patterns, onboarding-grade material) MUST inherit `kit:rules/lens-multi-model-review-pattern.md` and declare `--council` mode in their body. The inheritance contract is exactly 5 lines per the rule's "Inheritance contract" section: a `## --copilot mode` section citing the rule + a one-line synthesis lens, plus a frontmatter `inherits-rules` entry. The skill body MUST NOT redefine the dispatch mechanism (F-082), the agreement-table shape (F-083), or the hard-block rule (F-084) — those belong to the rule. If a skill needs a variant, it proposes a rule amendment via `/council-review` rather than forking. At minimum, the catalog skills `pr-review`, `code-reviewer`, `mad-spec`, `mad-plan`, `lens-aspnet-structure`, and `claude-md-refresh` MUST carry the contract.

## Acceptance scenarios

1. **Given** a skill with `blast_radius: 8` (e.g., a cross-team rule-authoring skill), **When** `/skill-audit` runs, **Then** the audit asserts the skill carries `inherits-rules: [rules/lens-multi-model-review-pattern.md]` AND a `## --copilot mode` body section with a one-line synthesis lens.
2. **Given** a skill that inherits the rule but redefines the agreement-table shape inline (forking the contract), **When** `/skill-audit` runs, **Then** the audit FAILS the skill with a "redefinition of inherited contract" finding.
3. **Given** the 6 anchor skills (`pr-review`, `code-reviewer`, `mad-spec`, `mad-plan`, `lens-aspnet-structure`, `claude-md-refresh`), **When** the wiring coverage report runs, **Then** all 6 skills declare `inherits-rules` AND a `## --copilot mode` body section.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multi-model/skill-audit-blast-radius-wiring.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/multi-model/skill-audit-fork-detection.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/multi-model/anchor-skills-coverage-report.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-082 (dispatch mechanism), F-083 (agreement-table), F-084 (hard-block), F-085 (fallback), F-086 (consent gate) — all upstream contracts must be GREEN before skills can rely on them
- **Soft:** F-077 (skill-audit infrastructure for blast-radius detection)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | § Inheritance contract — exact 5-line body block + frontmatter shape |
| kit:rules/skill-standards.md | Dimension 6 — multi-pass + cross-model options (the inheritance hook) |
| kit:rules/prescriptive-content-review.md | § Gap 5 — `blast_radius ≥ 7` auto-escalation trigger |
| ce:US-7 | User story payoff: high-blast-radius skills get the precision improvement |
| ce:FR-MULTI-001 | FR scope: which skills must adopt the cross-model adversarial review |
| cp:wave-002-wave-003-copilot-cli-design-review | First production rollout: showed inheritance contract works without forking |

## Implementation notes

(empty — populated when implementation begins)
