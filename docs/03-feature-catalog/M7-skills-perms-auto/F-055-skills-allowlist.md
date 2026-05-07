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
feature-id: F-055
short-slug: skills-allowlist
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - ce:US-6
    - cp:electron/skills.ts
    - cp:common/permission-servers.ts
    - kit:rules/canonical-skill-only.md
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
  LOCKED if GREEN AND reviews/F-055-skills-allowlist-review.md exists with verdict: ACCEPT.
depends-on: [F-051, F-052, F-054]
out-of-scope-notes: |
  Format is F-051; bundled installation is F-052; per-session toggle is F-053; custom-load is F-054.
  Version pinning by sha256 is F-056 (works WITH the allowlist — entry can pin a specific sha).
  Pin-expiry is F-057.
  3-tier permissions classification of allowlisted skills is F-058.
  Allowlist editing UI is M18 / settings UI (F-068).
  Network-fetched policy distribution (e.g., from a remote registry) is OUT OF SCOPE for v1.
confidence: high
---

# F-055 — Skills allowlist

## Behavior contract

The engine consults an allowlist at `<state-dir>/skills/allowlist.json` (and an optional org-level `<install-root>/policy/skills-allowlist.json` that wins when present, per least-privilege per `dangerous-operations-policy.md`). The allowlist shape is `{ entries: [{ name, source, optional sha256_pin, optional expires_utc }] }`. A skill that is registered via F-051..F-054 paths but is NOT in the allowlist is excluded from the active registry and recorded in the rejected-skills log with `reason: "not-on-allowlist"`. When the allowlist is missing, the default policy is `deny-all` (fail-closed per `dangerous-operations-policy.md` rule 7) — empty allowlist = no skills loadable. Per canonical-e US-6 (allowlist + pinning), the allowlist is the authoritative source of truth for which third-party content the engine will execute.

## Acceptance scenarios

1. **Given** an allowlist with one entry `{ name: "processing-pdfs", source: "bundled" }` and a custom-loaded `loop` skill, **When** the engine registers, **Then** `processing-pdfs` is active AND `loop` is rejected with `reason: "not-on-allowlist"` recorded in `<state-dir>/skills/rejected.jsonl`.
2. **Given** no allowlist file exists at any tier, **When** the engine starts, **Then** the active registry is empty AND a warning is logged `{ event: "ALLOWLIST_MISSING_FAIL_CLOSED", action: "deny-all" }`.
3. **Given** an org-level allowlist that excludes `m-code-review` AND a user-level allowlist that includes it, **When** the engine resolves, **Then** `m-code-review` is rejected (org-level wins) and the rejection log records `policy_tier: "org"`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/skills/allowlist-deny-not-listed.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/skills/allowlist-missing-fail-closed.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/skills/allowlist-org-overrides-user.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-051 (SKILL.md format the allowlist names), F-052 (bundled skills are common entries), F-054 (custom-loaded skills are subject to allowlist)
- **Soft:** F-056 (allowlist entry may carry a sha256 pin), F-057 (allowlist entry may carry an expiry)
- **Independent:** F-058..F-066 (perms + automations are downstream of allowlist; allowlist is the gate that runs before perms classification)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "allowlist" is item 5 of the M7 catalog list |
| ce:US-6 | Canonical-e user story for "allowlist + pinning" — third-party content controls |
| cp:electron/skills.ts | Reference allowlist-consultation pattern at registration time |
| cp:common/permission-servers.ts | Pattern for tiered policy resolution (preset configurations) |
| kit:rules/canonical-skill-only.md | Skill bodies are the canonical authors; allowlist gates which authors are admitted |
| kit:rules/dangerous-operations-policy.md | Fail-closed on missing allowlist; least-privilege default |

## Implementation notes

(empty — populated when implementation begins)
