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
feature-id: F-068
short-slug: settings-ui
milestone: M8
provenance:
  surfaces:
    - foundational-plan:M8 § Settings & persistence
    - cp:settings-ui (clawpilot SettingsModal / preferences panel)
    - kit:rules/dangerous-operations-policy.md (consent gates on telemetry opt-in)
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
  LOCKED if GREEN AND reviews/F-068-settings-ui-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-038, F-067]
out-of-scope-notes: |
  Per-automation-rule editor UI is F-069 (separate feature; F-068 owns the chrome only).
  Encrypted-import/export UI is F-072 (separate feature).
  Workspace switcher UI is F-074 (separate feature).
  In-place keybinding remap (chord shortcuts, custom keymaps) is v1.5.
  Settings search / filter UI is v1.5; v1 ships with section-tab navigation.
confidence: high
---

# F-068 — Settings UI

## Behavior contract

The desktop shell exposes a Settings surface (modal dialog or dedicated tab) with seven canonical sections: **Model** (provider + model + cost-tier hint per F-035), **Personality** (preset picker per F-036), **System Prompts** (composition per F-037), **MCP Servers** (BYO add/remove per F-049), **Permissions** (3-tier allowlist per F-058), **Theme** (light/dark/system per F-039), **Telemetry** (opt-in/opt-out per F-113). All controls are theme-token-only and ARIA-correct (per F-038). Edits are persisted to `settings.json` (per F-067) on commit (Save) or live (depending on control type — toggles save immediately; multi-line text fields require explicit Save). Unsaved changes display a dirty indicator + warn-on-close. Telemetry opt-in changes emit a consent dialog per `kit:rules/dangerous-operations-policy.md` (data-collection scope is a destructive action class).

## Acceptance scenarios

1. **Given** the user opening Settings, **When** the modal renders, **Then** all seven sections (Model / Personality / System Prompts / MCP Servers / Permissions / Theme / Telemetry) are accessible via tabs or scroll-anchors + keyboard navigation works (Tab moves focus; Esc closes).
2. **Given** the user toggling Theme from light to dark, **When** the toggle fires, **Then** the change applies immediately to the live UI (per F-039) + `settings.json:theme` is updated atomically + the modal does not show a dirty state.
3. **Given** the user enabling Telemetry opt-in, **When** they click the toggle, **Then** a consent dialog appears showing the data-collection scope + the toggle is NOT applied until the user explicitly confirms.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/desktop/settings-ui-sections.test.tsx` | browser | RED | scenario 1 |
| (TBD) `tests/browser/desktop/settings-ui-theme-toggle.test.tsx` | browser | RED | scenario 2 |
| (TBD) `tests/browser/desktop/settings-ui-telemetry-consent.test.tsx` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window hosts the modal), F-038 (primitives for tabs/toggles/text fields), F-067 (settings shape)
- **Soft:** F-035 (Model section sourcing), F-036 (Personality preset list), F-037 (system message composition), F-049 (MCP server management), F-058 (permissions tier), F-039 (theming), F-113 (telemetry opt-in)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M8 | Catalog declaration "shape, **UI**, ..." |
| cp:settings-ui | Clawpilot SettingsModal pattern (section tabs, save-on-commit) |
| kit:rules/dangerous-operations-policy.md | Telemetry-opt-in consent gate pattern |

## Implementation notes

(empty — populated when implementation begins)
