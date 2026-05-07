---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-d)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-004 / lane-d
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-075
short-slug: workspace-persistence
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - foundational-plan:Message-11 (NEW — project workspace state durability)
    - kit:rules/concurrency-safety.md (atomic write of active-workspace pointer)
    - kit:rules/canonical-artifact-frontmatter.md (workspace.json carries explicit version + owner_alias)
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
  LOCKED if GREEN AND reviews/F-075-workspace-persistence-review.md exists with verdict: ACCEPT.
depends-on: [F-067, F-073, F-008]
out-of-scope-notes: |
  Workspace history (auto-snapshot on every change) is v1.5; v1 persists only the current state.
  Cross-machine workspace sync (live, not via F-072 export) is v1.5.
  Workspace export to a portable bundle (single-workspace subset of F-072) is v1.5; v1 exports the full <state-dir>.
  Conflict resolution when two engine processes write the same workspace.json simultaneously is handled by `kit:rules/concurrency-safety.md` last-write-wins; richer merge semantics is v1.5.
  Workspace versioning / schema migration across releases is M19 deferred (F-D-004).
  D-5 (workspace storage layout default = single root with `<state-dir>/workspaces/<workspace-id>/` subtree) governs F-075's on-disk paths — see docs/10-backlog/design-decisions-pending.md.
confidence: high
---

# F-075 — Workspace persistence

## Behavior contract

Workspace state survives engine restarts. The active-workspace ID is persisted in `<state-dir>/active-workspace.json` (`{ "version": 1, "workspace_id": "<id>", "switched_at_utc": "<iso>" }`) — a single small file written atomically (per `kit:rules/concurrency-safety.md` §2) on every workspace switch. Per-workspace configuration lives in `<state-dir>/workspaces/<workspace-id>/workspace.json` (`{ "version": 1, "id": "<id>", "display_name": "...", "owner_alias": "...", "created_utc": "...", "last_active_utc": "...", "enabled_skills": [...], "mcp_allowlist": [...], "permission_tier": "...", "personality_override": "...", "system_prompt_append": "..." }`). Each workspace's run history (per F-008) is stored under `<state-dir>/workspaces/<workspace-id>/runs/` so deleting a workspace removes its runs without touching others. On engine startup, F-075 reads `active-workspace.json` + loads the referenced workspace; if the file is missing or references a non-existent workspace ID, the engine falls back to `default` + records a structured warning (per `kit:rules/degradation-fallback-policy.md` Rule 3). Renaming a workspace updates `display_name` only; the `id` is immutable so paths stay valid.

## Acceptance scenarios

1. **Given** the user switching from `default` to `client-acme` + closing the engine, **When** the engine restarts, **Then** the active workspace is `client-acme` (read from `active-workspace.json`) + the rail (per F-033) shows `client-acme` runs + no manual switch is needed.
2. **Given** an `active-workspace.json` referencing `workspace_id: "deleted-acme"` (a workspace that was deleted between sessions), **When** the engine starts, **Then** the engine falls back to `default` + writes a structured warning to the audit log (`WORKSPACE_NOT_FOUND, fallback to default`) + the warning is surfaced in the info panel (per F-034 Context Gap pattern).
3. **Given** the user renaming `client-acme` to `client-acme-corp` (display name change only), **When** the rename completes, **Then** `<state-dir>/workspaces/client-acme/workspace.json:display_name` is updated atomically + the directory path stays `client-acme/` + all run paths remain valid + the switcher (per F-074) shows the new display name immediately.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/workspace/active-workspace-restart.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/workspace/missing-workspace-fallback.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/workspace/rename-immutable-id.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-067 (settings.json schema awareness for workspace overlay), F-073 (workspace data model), F-008 (storage layout defines `<state-dir>/workspaces/`)
- **Soft:** F-074 (switcher UI consumes the persistence API), F-070 (workspace.json + active-workspace.json are encryption targets), F-072 (import/export covers per-workspace runs)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "..., persistence." |
| foundational-plan:Message-11 | NEW — project workspace must survive restart |
| kit:rules/concurrency-safety.md | Atomic write for `active-workspace.json` + `workspace.json` |
| kit:rules/canonical-artifact-frontmatter.md | Versioned, owner_alias-bearing JSON shape |
| kit:rules/degradation-fallback-policy.md | Missing-workspace fallback to default + Context Gap |

## Implementation notes

(empty — populated when implementation begins)

## Open decisions

- **D-5** (workspace storage layout default = single root `<state-dir>/workspaces/<workspace-id>/` subtree, vs separate `<state-dir>` per workspace) — pending. See `docs/10-backlog/design-decisions-pending.md`. This ledger assumes the single-root layout. If D-5 closes for separate roots, F-075 paths shift to `<workspace-state-dir>/workspace.json` + `<workspace-state-dir>/runs/`; persistence semantics (atomic write, version field, fallback path) are unchanged.
