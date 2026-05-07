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
feature-id: F-059
short-slug: permissions-rules
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/permission-patterns.ts
    - cp:electron/permission-pattern-guardrails.ts
    - cp:electron/permission-shell-syntax.ts
    - cp:src/features/permissions/ShellPatternsSection.tsx
    - cp:common/permission-servers.ts
    - kit:rules/dangerous-operations-policy.md
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
  LOCKED if GREEN AND reviews/F-059-permissions-rules-review.md exists with verdict: ACCEPT.
depends-on: [F-058]
out-of-scope-notes: |
  3-tier classification is F-058; this feature defines the rule shapes that classification consults.
  Audit-log of every rule match is F-060.
  Per-automation rule overrides are F-066.
  Pattern-import from preset configurations (e.g., "git-readonly" preset) is F-068 / settings UI.
  ReDoS protection on user-supplied regex: rejected pattern with redos-like complexity per pattern-guardrails.
configurable: |
  Match precedence is exact > prefix > regex; ties broken by most-recently-added.
  Regex patterns are anchored with implicit `^` and `$`; partial-match patterns must use explicit `.*`.
confidence: high
---

# F-059 — Permissions rules (per-command + regex)

## Behavior contract

A permission rule is a tuple `{ id, kind: "exact" | "prefix" | "regex", pattern, tier: ALLOW | ASK | DENY, scope: "global" | "per-session" | "per-automation", source }`. The classifier (F-058) evaluates rules in precedence order: exact match → prefix match → regex match (most recently added wins ties). Regex rules are screened by a guardrails layer that rejects patterns exceeding a complexity threshold (catastrophic-backtracking class), unanchored patterns missing `.*` semantics, and patterns containing forbidden constructs (e.g., `(?:.*)*`). Shell-command rules go through a syntax-aware splitter (`permission-shell-syntax.ts`-style) so `git status` matches `git\s+status` regardless of arg padding, and chained commands (`a && b`) are evaluated against each sub-command independently.

## Acceptance scenarios

1. **Given** rules `[{kind: "exact", pattern: "shell.git status", tier: ALLOW}, {kind: "prefix", pattern: "shell.git ", tier: ASK}]` and an invocation `shell.git status`, **When** the classifier runs, **Then** the resolved tier is `ALLOW` (exact match wins over prefix).
2. **Given** a regex rule `{ kind: "regex", pattern: "^shell\\.git (status|log|diff)$", tier: ALLOW }` and invocation `shell.git fetch`, **When** the classifier runs, **Then** the regex does not match AND the tier falls to default `ASK`.
3. **Given** a user attempts to add the regex pattern `(a+)+`, **When** the guardrails layer evaluates, **Then** the rule is rejected with `REGEX_REDOS_RISK` and the rule is NOT persisted.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/permissions/rule-precedence-exact-over-prefix.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/permissions/rule-regex-no-match-falls-to-default.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/permissions/rule-redos-guardrail-rejection.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-058 (3-tier classification consults these rules)
- **Soft:** F-060 (audit log records every rule match), F-066 (per-automation rules are this feature's `scope: "per-automation"` flavor)
- **Independent:** F-051..F-057 (skills), F-061..F-066 (automations base)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "rules" is item 9 of the M7 catalog list |
| cp:electron/permission-patterns.ts | Reference rule-shape + matching logic |
| cp:electron/permission-pattern-guardrails.ts | ReDoS / unanchored-pattern guardrails |
| cp:electron/permission-shell-syntax.ts | Shell-command-aware splitting (chained commands handled per sub-command) |
| cp:src/features/permissions/ShellPatternsSection.tsx | UI surface for shell-pattern rule editing |
| cp:common/permission-servers.ts | Preset configurations imported as rule sets |
| kit:rules/dangerous-operations-policy.md | Default-to-ASK + ReDoS-rejection are policy floor |

## Implementation notes

(empty — populated when implementation begins)
