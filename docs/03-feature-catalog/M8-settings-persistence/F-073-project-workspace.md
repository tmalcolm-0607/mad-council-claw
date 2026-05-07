---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-d)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-004 / lane-d
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet — surface is NEW per user Message 11"
feature-id: F-073
short-slug: project-workspace
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - foundational-plan:Message-11 (NEW — "Daily briefing + project workspace")
    - kit:rules/single-owner-accountability.md (workspace owner_alias)
    - kit:rules/no-invented-constraints.md (no implicit workspace caps)
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
  LOCKED if GREEN AND reviews/F-073-project-workspace-review.md exists with verdict: ACCEPT.
depends-on: [F-067, F-008]
out-of-scope-notes: |
  Cross-workspace shared resources (e.g. one MCP server enabled in workspace A and B simultaneously) is supported via per-workspace allowlist of global registrations — full server-instance sharing is v1.5.
  Per-workspace cost-budget caps (separate cap per workspace) is v1.5.
  Workspace templates (start a new workspace from a snapshot) is v1.5.
  Cloud-synced workspaces are M19 deferred (F-D-004 schema migration).
  Workspace switcher UI is F-074 (separate feature).
  Workspace persistence semantics are F-075 (separate feature).
  D-5 (workspace storage layout default = single root with `<state-dir>/workspaces/<workspace-id>/` subtree) is OPEN — see docs/10-backlog/design-decisions-pending.md.
confidence: high
---

# F-073 — Project workspace

> **NEW per user Message 11** ("Daily briefing + project workspace"). No clawpilot or canonical-e source surface — this is an emergent v1 requirement. Workspaces group sessions / skills / MCP servers / permissions / personalities per project.

## Behavior contract

A workspace is a named, isolated configuration scope that overlays global settings (per F-067). The default workspace is `default` (always present, cannot be deleted). Additional workspaces are user-created with a slug (`^[a-z0-9-]+$`) + display name + optional description. Each workspace owns: its own session history (per F-033 left rail filtered by workspace), its own enabled-skill subset (per F-053 of the global skill catalog F-051), its own MCP server allowlist (subset of F-049 registered servers), its own permission tier (per F-058) when stricter than global, its own personality/system-message overrides (per F-036/F-037). Global settings (per F-067) act as the base layer; workspace settings overlay only the keys they explicitly set. Workspaces are stored under `<state-dir>/workspaces/<workspace-id>/workspace.json` (default proposed layout per D-5; subject to that decision's closure). Each workspace carries an explicit `owner_alias` per `kit:rules/single-owner-accountability.md` even when there is only one local user — the field is load-bearing for future multi-user scenarios + audit. Per `kit:rules/no-invented-constraints.md`, NO implicit cap on workspace count is enforced; if the user wants 100 workspaces, the system supports it.

## Acceptance scenarios

1. **Given** a fresh install, **When** the engine starts, **Then** a `default` workspace exists + `<state-dir>/workspaces/default/workspace.json` is present with `owner_alias` set to the current OS user + the active workspace is `default`.
2. **Given** the user creating workspace `client-acme` with `permission_tier: read` (stricter than global `write`), **When** an automation in that workspace tries to invoke a write-tier tool, **Then** the call is denied with `WORKSPACE_PERMISSION_DENIED` + the global-level permission is irrelevant + the audit log records the workspace-id.
3. **Given** workspaces `default` and `client-acme` with different MCP server allowlists, **When** the user switches from `default` to `client-acme`, **Then** the engine disconnects servers no longer in the allowlist + connects servers newly in the allowlist + the active workspace ID is persisted (per F-075) + sessions in the rail (per F-033) filter to only `client-acme` runs.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/workspace/default-workspace-bootstrap.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/workspace/per-workspace-permission-tier.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/workspace/workspace-switch-mcp-reconcile.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-067 (global settings is the base overlay), F-008 (storage layout defines `workspaces/` subtree)
- **Soft:** F-033 (rail filters by active workspace), F-049 (MCP allowlist subset), F-053 (skill toggle scoped per workspace), F-058 (per-workspace permission tier), F-036/F-037 (personality/system-message overrides)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "..., project workspace, ..." |
| foundational-plan:Message-11 | NEW — project workspace as v1 must-have |
| kit:rules/single-owner-accountability.md | Pattern: workspace.json carries explicit owner_alias |
| kit:rules/no-invented-constraints.md | No implicit workspace count cap; user-set caps only |

## Implementation notes

(empty — populated when implementation begins)

## Open decisions

- **D-5** (workspace storage layout default = single root `<state-dir>/workspaces/<workspace-id>/` subtree, vs separate `<state-dir>` per workspace) — pending. See `docs/10-backlog/design-decisions-pending.md`. This ledger assumes single-root layout; if D-5 closes otherwise, F-070/F-071/F-072 envelope contracts hold either way (encryption is per-file, not per-tree).
