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
feature-id: F-074
short-slug: workspace-switcher-ui
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - foundational-plan:Message-11 (NEW — project workspace UI surface)
    - cp:src/main/index.ts (window chrome host pattern)
    - kit:rules/dangerous-operations-policy.md (consent on workspace delete)
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
  LOCKED if GREEN AND reviews/F-074-workspace-switcher-ui-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-038, F-073]
out-of-scope-notes: |
  Drag-and-drop workspace reordering is v1.5; v1 sorts by last-active.
  Workspace icons / color customization is v1.5.
  Per-workspace badge counts (unread runs, halted automations) are v1.5; v1 shows just the workspace name.
  Multi-window with different active workspaces (per F-043 multi-window) is v1.5; v1 binds active workspace to the engine process.
  Search / filter the workspace list is v1.5; v1 ships with a flat list.
confidence: high
---

# F-074 — Workspace switcher UI

## Behavior contract

The desktop shell exposes a workspace switcher in the window chrome (top-left or top-bar dropdown, theme-aware per F-039). The control shows the current workspace name + a chevron; clicking opens a dropdown listing all workspaces sorted by last-active descending, with the default workspace pinned to the bottom and a "+ New workspace..." action at the top. Selecting a workspace switches the active workspace (per F-073 reconcile path) + emits a `workspaceSwitched` IPC event so all window panes (rail per F-033, info-panel per F-034, model picker per F-035) refresh. Creating a new workspace opens a dialog requesting slug + display name + optional copy-from existing workspace. Deleting a non-default workspace is a Dangerous Operation per `kit:rules/dangerous-operations-policy.md`: a confirmation dialog shows the impact (N runs, M skill toggles, K MCP allowlist entries) + requires the user to type the workspace name to confirm. The `default` workspace is non-deletable + the delete action is hidden for it.

## Acceptance scenarios

1. **Given** three workspaces (`default`, `client-acme`, `personal`) + the user clicking the switcher chevron, **When** the dropdown opens, **Then** all three workspaces are listed with last-active timestamps + the currently-active workspace shows a check/highlight + the "+ New workspace..." action is at the top of the list.
2. **Given** the user selecting `client-acme` from the switcher, **When** the selection is made, **Then** the active workspace flips to `client-acme` (per F-073) + the rail (F-033) refreshes to client-acme runs only + the model picker (F-035) reflects client-acme's enabled MCP/skill subset + the change persists across restart (per F-075).
3. **Given** the user attempting to delete the `default` workspace, **When** the user opens the workspace context menu, **Then** the Delete action is absent or disabled + a tooltip explains "the default workspace cannot be deleted" + no consent dialog appears.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/desktop/workspace-switcher-list.test.tsx` | browser | RED | scenario 1 |
| (TBD) `tests/browser/desktop/workspace-switcher-select.test.tsx` | browser | RED | scenario 2 |
| (TBD) `tests/browser/desktop/workspace-switcher-default-undeletable.test.tsx` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window chrome hosts the control), F-038 (Dropdown / Dialog primitives), F-073 (workspace data model + reconcile path)
- **Soft:** F-039 (theme tokens), F-040 (keyboard shortcut Ctrl/Cmd-K to open switcher), F-033/F-034/F-035 (panes refresh on switch event), F-075 (active-workspace persistence)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "..., switcher UI, ..." |
| foundational-plan:Message-11 | NEW — project workspace surface needs a switcher |
| cp:src/main/index.ts | Window chrome host pattern |
| kit:rules/dangerous-operations-policy.md | Type-name-to-confirm pattern for delete |

## Implementation notes

(empty — populated when implementation begins)
