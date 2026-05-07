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
feature-id: F-058
short-slug: permissions-3tier
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/permission-policy.ts
    - cp:electron/permission-classifier.ts
    - cp:electron/permission-classifier-types.ts
    - cp:src/features/permissions/PermissionsPanel.tsx
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
  LOCKED if GREEN AND reviews/F-058-permissions-3tier-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-007]
out-of-scope-notes: |
  Per-command + regex rules atop the 3-tier classification are F-059.
  Audit-log of permission decisions is F-060.
  Per-automation permissions are F-066 / settings (F-069).
  Calendar-aware permissions (time-window-bounded grants) are v1.5.
  The 3 tiers are: ALLOW (auto-execute), ASK (interactive consent), DENY (blocked, never executes). Quad-state expansions (ALLOW_BOUNDED, etc.) are deferred.
configurable: |
  Tier names are fixed in v1; changing names is OUT OF SCOPE per `rules/non-negotiable-rules.md` (verb-bound).
confidence: high
---

# F-058 — Permissions 3-tier

## Behavior contract

Every tool invocation, MCP call, shell command, file write, and network request is classified into one of three permission tiers: `ALLOW` (executes silently), `ASK` (engine emits a consent prompt and waits for explicit user approval before proceeding, per `dangerous-operations-policy.md`), or `DENY` (refused; the requestor receives `PERMISSION_DENIED` with the matched policy entry). Classification is performed by a deterministic policy engine (`permission-policy.ts`-style) that reads `<state-dir>/permissions/policy.json` AND `<install-root>/policy/permissions.json` (org-level wins on conflict). Default tier is `ASK` (fail-towards-friction, never fail-open per `dangerous-operations-policy.md` rule 7). Classification result is stable for the same input — same call → same tier — to avoid surprise escalations mid-session.

## Acceptance scenarios

1. **Given** policy `{ "shell.git status": "ALLOW" }` and a tool invocation `shell.git status`, **When** the engine classifies, **Then** the tier is `ALLOW` and execution proceeds without prompting.
2. **Given** no policy entry for `shell.rm -rf /tmp/foo`, **When** classification runs, **Then** the default tier is `ASK` and the engine emits a consent prompt with the full command + context before any execution.
3. **Given** an org-level policy that DENIES `mcp.network-fetch.*` and a user-level policy that ALLOWs `mcp.network-fetch.api.example.com`, **When** the engine resolves, **Then** the result is `DENY` (org-level wins) and the requestor sees `PERMISSION_DENIED { policy_tier: "org" }`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/permissions/3tier-allow-classification.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/permissions/3tier-ask-default.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/permissions/3tier-org-overrides-user.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel hosts the policy engine), F-007 (IPC contract surfaces ALLOW/ASK/DENY decisions to the UI for prompt rendering)
- **Soft:** F-055 (allowlist for skills is structurally analogous; both are deny-default policy tables), F-066 (per-automation perms are scoped overrides of the default policy)
- **Independent:** F-051..F-057 (skills register orthogonally; their tools go through this classifier)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "3-tier perms" is item 8 of the M7 catalog list |
| cp:electron/permission-policy.ts | 1,331-LOC reference implementation of the policy engine |
| cp:electron/permission-classifier.ts | Tier classification logic |
| cp:electron/permission-classifier-types.ts | Type contract for tiered decisions |
| cp:src/features/permissions/PermissionsPanel.tsx | UI surface that renders the tier per command |
| kit:rules/dangerous-operations-policy.md | Default-to-ASK / fail-closed-on-missing-policy / explicit-consent semantics |

## Implementation notes

(empty — populated when implementation begins)
