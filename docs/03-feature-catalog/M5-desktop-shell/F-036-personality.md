---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-036
short-slug: personality
milestone: M5
provenance:
  surfaces:
    - cp:src/features/chat/components/PersonalityPicker.tsx
    - cp:electron/ipc/personality-ipc.ts
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
  LOCKED if GREEN AND reviews/F-036-personality-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-037]
out-of-scope-notes: |
  User-authored personality presets (saving + sharing custom presets between users) is v1.5.
  Personality A/B testing (comparing two presets on the same input) is v1.5.
  Personality marketplace / import-from-URL is out of scope for v1.
confidence: high
---

# F-036 — Personality presets

## Behavior contract

The desktop ships a fixed set of canonical personality presets (e.g., `professional`, `friendly`, `terse`, `verbose`, `code-focused`) — the v1 list is enumerated in `<install-dir>/desktop/personality-presets.json` and is not user-editable. Selecting a preset in the new-run dialog (or via the picker in the run header for an active run) sets the run's `system_message` (per F-037) to the preset's bundled text + persists `selected_personality_id` into the run config. Personalities are independent of model picker (F-035) — any model can be paired with any personality. The preset's text is cite-able + audit-logged: when a run starts with `personality_id: friendly`, the audit log entry references the preset's content sha256 so historical runs remain reproducible even if presets change in later versions.

## Acceptance scenarios

1. **Given** a fresh install with 5 bundled presets, **When** the new-run dialog opens, **Then** the personality picker lists all 5 with name + 1-line description preview.
2. **Given** the user selecting "terse" + spawning a new run, **When** the run starts, **Then** the run config carries `personality_id: terse` + the audit log's first entry references `personality_content_sha256: <hash>` matching the bundled preset's content.
3. **Given** an existing run audit log referencing `personality_content_sha256` of a no-longer-bundled preset version, **When** the run is opened in the desktop, **Then** the personality field shows the preset name + "(historical version, not currently bundled)" — content is still readable from the audit log.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/desktop/personality-picker-list.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/integration/desktop/personality-audit-trace.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/desktop/personality-historical.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window), F-037 (system message — personality text becomes the run's system_message)
- **Soft:** F-015 (audit log carries personality_content_sha256), F-035 (picker UX coexistence)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/features/chat/components/PersonalityPicker.tsx | Preset picker UI |
| cp:electron/ipc/personality-ipc.ts | IPC namespace pattern for personality operations |

## Implementation notes

(empty — populated when implementation begins)
